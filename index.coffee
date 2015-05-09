request = require 'superagent'
express = require 'express'
bodyParser = require 'body-parser'
cors = require 'cors'
stats = require './stats'
s3Utility = require './lib/s3-utility'
tarArchive = require './lib/tar-archive'
synapseInputJSON = require './resources/synapse-json'
fs = require 'fs'
startSynapse = require './lib/start-synapse'



app = express()
server = require('http').Server(app)
io = require('socket.io')(server)

#global variables
synapseStarted = false
baseURL = 'http://localhost:4243'
runningContainers = []

app.use cors()
app.use bodyParser.json()
server.listen(8080)

io.on 'connection', (socket) ->
  console.log("socket connected")
  #get list of containers
  request
  .get("#{baseURL}/containers/json")
  .end (err, res) ->
    if(err)
      console.log("error in getting list of containers:#{err}")
    else
      res.body.forEach((container) ->
        containerId = container.Id
        #call getStats for each container with socket
        stats.getStats(containerId, socket)
      )




app.get '/images', (req, res) ->
  request
    .get("#{baseURL}/images/json")
    .end (err, dockerResponse) ->
      if dockerResponse.ok
        console.log 'got response from DOCKER remote API'
        console.log dockerResponse.body
        res.json(dockerResponse.body)
      else
        console.log("error:#{err}")
        res.status(dockerResponse.status).end()

app.post '/containers/create', (req, res) ->
  imageName = req.body.ImageName
  bucketName = req.body.BucketName
  fileName = req.body.FileName
  containerName = req.body.ContainerName
  #getting tar file from s3
  s3Utility.getFile(bucketName, fileName).then (destPath) ->
    console.log("pulled from s3 and about to unpack")
    #unpacking the tar file in tmp folder
    tarArchive(destPath, fileName).then ->
      console.log("files extracted onto tmp directory")
      user = "ubuntu"
      memory = 100 * 1024 #bytes
      #creating the container
      request
        .post("#{baseURL}/containers/create?name=#{containerName}")
        .send({"Image": imageName, "Tty":true,"AttachStdin":true,"OpenStdin":true, "Volumes":{"/tmp":{}
          },"WorkingDir":"/tmp", "Cmd":["node","index.js"],"ExposedPorts":{"3000/tcp":{}}})
        .set('Content-type','application/json')
        .end (err, dockerResponse) ->
          if(err)
            console.log("error in creating container:#{err}")
            res.status(dockerResponse.status).end()
          else
            console.log 'created the container'
            console.log dockerResponse.body
            #starting the container
            containerId = dockerResponse.body.Id
            #console.log containerId
            #keeping track of running container ids for hot deploy..also check for imageName
            if(imageName == "node")
              runningContainers.push(containerId)
            request
              .post("#{baseURL}/containers/#{containerId}/start")
              .send({"PublishAllPorts":true, "Binds":"#{destPath}#{fileName.split('.')[0]}:/tmp:rw","PortBindings":{"3000/tcp":[{}]}})
              .set('Content-type','application/json')
              .end (err, dockerResponse) ->
                if(err)
                  console.log("error in starting container:#{err}")
                  res.status(dockerResponse.status).end()
                else
                  console.log 'started the container'
                  console.log dockerResponse.body
                  #writing synapseInputJSON to file /etc/synapse.json.conf
                  synapseJSON = JSON.parse(synapseInputJSON)
                  synapseJSON.services.nodesrv.discovery.image_name = "node"
                  #console.log("synapseJSON:"+synapseJSON)
                  if(synapseStarted == false && imageName == "node")
                    fs.writeFile("#{process.cwd()}/synapse.json.conf", JSON.stringify(synapseJSON), (err) ->
                      if(err)
                        console.log("error in writing synapse json conf file :#{err}")
                      console.log("wrote synapse.json.conf to filesystem")
                      #start synapse
                      #add condition for running synapse only for node images .. imageName == "node"

                      startSynapse().then ->
                        console.log("synapse exited")
                      synapseStarted = true
                      console.log("synapse started")
                      res.json({"containerId":containerId}).end()
                    )
                  res.json({"containerId":containerId})


app.post '/containers/terminate', (req, res) ->
  containerId = req.body.containerId
  console.log containerId
  request
    .post("#{baseURL}/containers/#{containerId}/stop")
    .set('Content-type','application/json')
    .end (err, dockerResponse) ->
      if dockerResponse.ok
        console.log 'got response from DOCKER remote API'
        console.log dockerResponse.body
        res.json(dockerResponse.body)
      else
        console.log("error:#{err}")
        res.status(dockerResponse.status).end()

app.post '/containers/hotdeploy', (req, res) ->

  runningContainers.forEach((containerId) ->
      console.log containerId
      request
        .post("#{baseURL}/containers/#{containerId}/stop")
        .set('Content-type','application/json')
        .end (err, dockerResponse) ->
          if dockerResponse.ok
            console.log "hot deploy terminate - killing container with id #{containerId}"
            console.log dockerResponse.body
          else
            console.log("error:#{err}")
            res.status(500).end()
  )
  res.send(200).end()

app.get '/containers', (req, res) ->
  request
    .get("#{baseURL}/containers/json?all=1")
    .end (err, dockerResponse) ->
      if dockerResponse.ok
        console.log 'got response from DOCKER remote API'
        console.log dockerResponse.body
        res.json(dockerResponse.body)
      else
        console.log("error:#{err}")
        res.status(dockerResponse.status).end()

# app.post '/containers/stats', (req, res) ->
#   containerId = req.body.containerId
#   console.log containerId
#   stats.getStats(containerId)
#   res.status(200).end()
