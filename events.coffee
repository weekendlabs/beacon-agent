oboe = require 'oboe'
humanize = require 'humanize'

previousCpu = 0.0
previousSystem = 0.0
previousMemoryUsage = 0.0
previousNetworkUsage = 0.0

calculateCPUPercent = (statItem, previousCpu, previousSystem) ->
  cpuDelta = statItem.cpu_stats.cpu_usage.total_usage - previousCpu
  systemDelta = statItem.cpu_stats.system_cpu_usage - previousSystem

  cpuPercent = 0.0
  if (systemDelta > 0.0 && cpuDelta > 0.0)
      cpuPercent = (cpuDelta / systemDelta) * statItem.cpu_stats.cpu_usage.percpu_usage.length * 100.0

  cpuPercent

module.exports = (io) ->
  oboe("http://localhost:4243/events")
    .done((res) ->
      console.log res
      io.sockets.emit('container-event', res)
      if res.status is 'start'
        oboe("http://localhost:4243/containers/#{res.id}/stats")
          .done((stat) ->
            memPercent = (stat.memory_stats.usage - previousMemoryUsage ) / stat.memory_stats.limit
            previousMemoryUsage = stat.memory_stats.usage

            networkUsage = humanize.filesize(stat.network.rx_bytes - previousNetworkUsage)
            previousNetworkUsage = networkUsage

            cpuPercent = calculateCPUPercent(stat, previousCpu, previousSystem)
            previousCpu = stat.cpu_stats.cpu_usage.total_usage
            previousSystem = stat.cpu_stats.system_cpu_usage
            console.log("#{memPercent} #{networkUsage} #{cpuPercent}")

            io.sockets.emit('stat', { containerId: res.id, m: memPercent, n: networkUsage, c: cpuPercent})
          )
    )
    .fail(->
      console.log("failed")
    )
