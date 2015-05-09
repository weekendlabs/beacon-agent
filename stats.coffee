oboe = require 'oboe'
humanize = require('humanize')

previousCpu = 0.0
previousSystem = 0.0
previousMemoryUsage = 0.0
previousNetworkUsage = 0.0

getStats = (containerId, socket) ->
  oboe("http://localhost:4243/containers/#{containerId}/stats")
    .done((res) ->
      #-----------Memory-----------
      memPercent = (res.memory_stats.usage - previousMemoryUsage ) / res.memory_stats.limit
      console.log("memory percent:"+memPercent)
      previousMemoryUsage = res.memory_stats.usage


      #-----------Network-----------
      networkUsage = humanize.filesize(res.network.rx_bytes - previousNetworkUsage)
      console.log("Network usage:"+networkUsage)
      previousNetworkUsage = networkUsage


      #-----------CPU-----------
      cpuPercent = calculateCPUPercent(res, previousCpu, previousSystem)
      previousCpu = res.cpu_stats.cpu_usage.total_usage
      previousSystem = res.cpu_stats.system_cpu_usage
      console.log("cpu:"+cpuPercent)
      socket.emit('stats',{id:containerId, m:memPercent, n:networkUsage, c:cpuPercent})
    )
    .fail(->
      console.log("failed")
    )

calculateCPUPercent = (statItem, previousCpu, previousSystem) ->
  cpuDelta = statItem.cpu_stats.cpu_usage.total_usage - previousCpu
  systemDelta = statItem.cpu_stats.system_cpu_usage - previousSystem

  cpuPercent = 0.0
  if (systemDelta > 0.0 && cpuDelta > 0.0)
      cpuPercent = (cpuDelta / systemDelta) * statItem.cpu_stats.cpu_usage.percpu_usage.length * 100.0

  cpuPercent

module.exports =
  getStats:getStats
