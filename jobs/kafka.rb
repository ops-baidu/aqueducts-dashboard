@numOfPoints = 15
@kafkaHost = "dbl-aqueducts-kafka01.dbl01.baidu.com"
@kafkaPort = "8888"
@jmxcmdPath = "/home/work/bin/jmxcmd.jar"
@jmxBean = "kafka:type=kafka.BrokerAllTopicStat"
@period = 3

def getKafkaStatus(bean, key)
  value = `java -jar #{@jmxcmdPath} - #{@kafkaHost}:#{@kafkaPort} #{bean} #{key} 2>&1`
  return value.split(": ").last.to_i;
end

bytesIn = []
bytesOut = []
messagesIn = []

pointsIn = []
pointsOut = []
pointsMessagesIn = []

bytesIn <<  getKafkaStatus(@jmxBean, "BytesIn")
bytesOut << getKafkaStatus(@jmxBean, "BytesOut")
messagesIn << getKafkaStatus(@jmxBean, "MessagesIn")

(1..@numOfPoints).each do |i|
  bytesIn << getKafkaStatus(@jmxBean, "BytesIn")
  bytesOut << getKafkaStatus(@jmxBean, "BytesOut")
  messagesIn << getKafkaStatus(@jmxBean, "MessagesIn")

  pointsIn << { x: i, y: (bytesIn[i] - bytesIn[i - 1] ) / @period }
  pointsOut << { x: i, y: (bytesOut[i] - bytesOut[i - 1]) / @period }
  pointsMessagesIn << { x: i, y: (messagesIn[i] - messagesIn[i - 1]) / @period }
end

last_x = pointsIn.last[:x]

SCHEDULER.every "#{@period}s" do
  bytesIn.shift
  bytesOut.shift
  messagesIn.shift

  pointsIn.shift
  pointsOut.shift
  pointsMessagesIn.shift

  last_x += 1

  bytesIn << getKafkaStatus(@jmxBean, "BytesIn")
  bytesOut << getKafkaStatus(@jmxBean, "BytesOut")
  messagesIn << getKafkaStatus(@jmxBean, "MessagesIn")

  pointsIn << {x: last_x, y: (bytesIn[@numOfPoints] - bytesIn[@numOfPoints - 1]) / @period }
  pointsOut << {x: last_x, y: (bytesOut[@numOfPoints] - bytesOut[@numOfPoints - 1]) / @period }
  pointsMessagesIn << {x: last_x, y: (messagesIn[@numOfPoints] - messagesIn[@numOfPoints - 1]) / @period }

  send_event('bytesIn', points: pointsIn)
  send_event('bytesOut', points: pointsOut)
  send_event('messagesIn', points: pointsMessagesIn)
end
