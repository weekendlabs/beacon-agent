# Do npm install and return
P = require 'bluebird'
{exec} = require 'child_process'

module.exports = () ->
  console.log "starting synapse in current directory"

  new P (resolve, reject) ->
    child = exec('sudo synapse -c /home/ubuntu/beacon-agent/synapse.json.conf', {cwd: "#{process.cwd()}"})

    child.on 'error', (err) ->
      console.log "error in starting synapse: #{err}"

    child.on 'exit', (code) ->
      console.log "starting synapse exited with code: #{code}"
      resolve()
