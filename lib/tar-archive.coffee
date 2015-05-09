# Package in tar and return
P = require 'bluebird'
R = require 'ramda'
tar = require 'tar'
path = require 'path'
fse = require 'fs-extra'
fs = require 'fs'

module.exports = (destPath, archiveName) ->
  new P (resolve, reject) ->

    extractor = tar.Extract({path: destPath})
      .on 'error', (err) -> console.log("error:"+err)
      .on 'end', ->
        console.log("finished")
        resolve()

    fs.createReadStream(destPath + archiveName)
      .on 'error', -> (err) console.log("error:"+err)
      .pipe(extractor);
