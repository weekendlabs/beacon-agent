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
os = require 'os'


app = express()
server = require('http').Server(app)
io = require('socket.io')(server)

require('./events')(io)

#global variables
synapseStarted = false
baseURL = 'http://localhost:4243'
runningContainers = []

app.use cors()
app.use bodyParser.json()
server.listen(10000)

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
        .post("#{baseURL}/containers/create")
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
                  res.send(200).end()






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
    .get("#{baseURL}/containers/json")
    .end (err, dockerResponse) ->
      if dockerResponse.ok
        console.log 'got response from DOCKER remote API'
        console.log dockerResponse.body
        res.json(dockerResponse.body)
      else
        console.log("error:#{err}")
        res.status(dockerResponse.status).end()
