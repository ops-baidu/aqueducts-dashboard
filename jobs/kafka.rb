@numOfPoints = 15
@kafkaHost = "dbl-aqueducts-kafka01.dbl01.baidu.com"
@kafkaPort = "8888"
@jmxcmdPath = "/home/work/bin/jmxcmd.jar"
@jmxBean = "kafka:type=kafka.BrokerAllTopicStat"

def getKafkaStatus(bean, key)
  value = `java -jar #{@jmxcmdPath} - #{@kafkaHost}:#{@kafkaPort} #{bean} #{key} 2>&1`
  return value.split(": ").last.to_i;
end
  
bytesIn = []
bytesOut = []
pointsIn = []
pointsOut = []

bytesIn <<  getKafkaStatus(@jmxBean, "BytesIn")
bytesOut << getKafkaStatus(@jmxBean, "BytesOut")

(1..@numOfPoints).each do |i|
  bytesIn << getKafkaStatus(@jmxBean, "BytesIn")
  bytesOut << getKafkaStatus(@jmxBean, "BytesOut")
  
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
  
  bytesIn << getKafkaStatus(@jmxBean, "BytesIn")
  bytesOut << getKafkaStatus(@jmxBean, "BytesOut")
  
  pointsIn << {x: last_x, y: bytesIn[@numOfPoints] - bytesIn[@numOfPoints - 1] }
  pointsOut << {x: last_x, y: bytesOut[@numOfPoints] - bytesOut[@numOfPoints - 1] }
  
  send_event('bytesIn', points: pointsIn)
  send_event('bytesOut', points: pointsOut)
end
