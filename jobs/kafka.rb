def getKafkaStatus(key)
  value = `java -jar /home/work/bin/jmxcmd.jar - dbl-aqueducts-kafka01.dbl01.baidu.com:8888 kafka:type=kafka.BrokerAllTopicStat #{key} 2>&1`
  return value.split(": ").last.to_i;
end

bytesIn = []
bytesOut = []
pointsIn = []
pointsOut = []

bytesIn <<  getKafkaStatus("BytesIn")
bytesOut << getKafkaStatus("BytesOut")

#messagesIn = []
(1..20).each do |i|
  bytesIn << getKafkaStatus("BytesIn")
  bytesOut << getKafkaStatus("BytesOut")

  pointsIn << { x: i, y: bytesIn[i] - bytesIn[i - 1] }
  pointsOut << { x: i, y: bytesOut[i] - bytesOut[i - 1] }
end

last_x = pointsIn.last[:x]

SCHEDULER.every '3s' do
  bytesIn.shift
  bytesOut.shift
  pointsIn.shift
  pointsOut.shift

  last_x += 1

  bytesIn << getKafkaStatus("BytesIn")
  bytesOut << getKafkaStatus("BytesOut")

  pointsIn << {x: last_x, y: bytesIn[20] - bytesIn[19] }
  pointsOut << {x: last_x, y: bytesOut[20] - bytesOut[19] }

  send_event('bytesIn', points: pointsIn)
  send_event('bytesOut', points: pointsOut)
end
