AWS = require 'aws-sdk'
fs = require 'fs'
path = require 'path'
R = require 'ramda'
P = require 'bluebird'
fs = require 'fs'
fse = require 'fs-extra'

getFile = (bucketName, fileName) ->
  new P (resolve, reject) ->
    console.log("filename in s3 utility:#{fileName}")
    #cleaning up tmp directory before fetching file from s3
    destPath = "/home/ubuntu/tmp/"
    fse.remove destPath + fileName, (err) ->
      if(err)
        console.log("error:#{err}")
      else
        console.log("deleted tar file")

    console.log("#{destPath}#{fileName.split('.')[0]}")
    fse.remove destPath + (fileName.split('.')[0]), (err) ->
      if(err)
        console.log("error:#{err}")
      else
        console.log("deleted extracted directory")


    AWS.config.update({accessKeyId:'AKIAIAAZ7VPUJCPVXWFQ', secretAccessKey:'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', region:'us-west-2'})
    s3 = new AWS.S3()
    getObjectParams =
      Bucket: bucketName
      Key: fileName
    s3.getObject getObjectParams, (err, data) ->
      if(err)
        console.log("errr in get object:"+err);
      console.log("data obtained")
      fs.open destPath + fileName, 'w', (err, fd) ->
        if(err)
          console.log("error in opening file path"+err)
        else
          fs.write fd, data.Body, 0, data.Body.length, null, (err) ->
            if(err)
              console.log("error in writing file from buffer")
            fs.close fd, ->
              console.log("file written successfully")
              resolve(destPath)


module.exports =
  getFile: getFile
