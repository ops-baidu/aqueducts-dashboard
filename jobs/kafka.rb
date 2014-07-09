@numOfPoints = 15
#@kafkaHosts = ['cq01-aqueducts-kafka00.cq01', 'cq01-aqueducts-kafka02.cq01', 'cq01-aqueducts-kafka03.cq01', 'cq01-aqueducts-kafka04.cq01', 'cq01-aqueducts-kafka05.cq01', 'cq01-aqueducts-kafka06.cq01', 'db-aqueducts-kafka08.db01', 'db-aqueducts-kafka07.db01', 'cq01-aqueducts-kafka01.cq01']
@kafkaPort = "8888"
@jmxcmdPath = "/home/work/bin/jmxcmd.jar"
@jmxBean = "kafka:type=kafka.BrokerAllTopicStat"
@period = 5

@backup = 2 # kafka backup number

def get_brokers_from_zk
  require 'zookeeper'

  brokers = []
  zk = Zookeeper.new("10.36.4.185:2181")
  zk.get_children(:path => "/brokers/ids")[:children].each do |ids|
    broker_meta = zk.get(:path => "/brokers/ids/#{ids}")[:data]
    broker_meta_in_json = JSON.parse(broker_meta)
    brokers << broker_meta_in_json["host"]
  end
  zk.close
  return brokers
end

@kafkaHosts = get_brokers_from_zk

def getKafkaStatus(bean, kafkaHosts)
  total = 0
  kafkaHosts.each do |host|
    value = `java -jar #{@jmxcmdPath} - #{host}:#{@kafkaPort} '"kafka.server":name="#{bean}",type="BrokerTopicMetrics"' Count 2>&1`
    total += value.split(": ").last.to_i;
  end
  return total
end

bytesIn = []
bytesOut = []
messagesIn = []

pointsIn = []
pointsOut = []
pointsMessagesIn = []

bytesIn << getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHosts)
bytesOut << getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHosts)
messagesIn << getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHosts)

(1..@numOfPoints).each do |i|
  bytesIn << getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHosts)
  bytesOut << getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHosts)
  messagesIn << getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHosts)

  pointsIn << { x: i, y: (bytesIn[i] - bytesIn[i - 1] ) / @period }
  pointsOut << { x: i, y: (bytesOut[i] - bytesOut[i - 1]) / @period / @backup }
  pointsMessagesIn << { x: i, y: (messagesIn[i] - messagesIn[i - 1]) / @period / @backup }
end

last_x = pointsIn.last[:x]

flag = 0

SCHEDULER.every "#{@period}s", allow_overlapping: false do
  flag+=1
  if 100 == flag
    flag = 0
    @kafkaHosts = get_brokers_from_zk
  end

  bytesIn.shift
  bytesOut.shift
  messagesIn.shift

  pointsIn.shift
  pointsOut.shift
  pointsMessagesIn.shift

  last_x += 1

  bytesIn << getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHosts)
  bytesOut << getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHosts)
  messagesIn << getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHosts)

  pointsIn << {x: last_x, y: (bytesIn[@numOfPoints] - bytesIn[@numOfPoints - 1]) / @period }
  pointsOut << {x: last_x, y: (bytesOut[@numOfPoints] - bytesOut[@numOfPoints - 1]) / @period / @backup }
  pointsMessagesIn << {x: last_x, y: (messagesIn[@numOfPoints] - messagesIn[@numOfPoints - 1]) / @period / @backup }

  send_event('bytesIn', points: pointsIn)
  send_event('bytesOut', points: pointsOut)
  send_event('messagesIn', points: pointsMessagesIn)
end


# java -jar ~/nfs/jmxcmd.jar - cq01-aqueducts-kafka00.cq01:8888 '"kafka.server":name="AllTopicsBytesInPerSec",type="BrokerTopicMetrics"' OneMinuteRate
# java -jar ~/nfs/jmxcmd.jar - cq01-aqueducts-kafka00.cq01:8888 '"kafka.server":name="AllTopicsBytesOutPerSec",type="BrokerTopicMetrics"' OneMinuteRate
# java -jar ~/nfs/jmxcmd.jar - cq01-aqueducts-kafka00.cq01:8888 '"kafka.server":name="AllTopicsMessagesInPerSec",type="BrokerTopicMetrics"' OneMinuteRate
