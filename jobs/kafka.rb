@numOfPoints = 60
@kafkaPort = "8888"
@jmxcmdPath = "/home/work/bin/jmxcmd.jar"
@jmxBean = "kafka:type=kafka.BrokerAllTopicStat"
@zookeeperHuaBeiVIP = "10.36.4.185:2181"
@zookeeperHuaDongVIP = "10.202.6.13:2181"
@period = 5

@backup = 2 # kafka backup number

def get_brokers_from_zk(url)
  require 'zookeeper'

  brokers = []
  #zk = Zookeeper.new("10.36.4.185:2181")
  zk = Zookeeper.new(url)
  zk.get_children(:path => "/brokers/ids")[:children].each do |ids|
    broker_meta = zk.get(:path => "/brokers/ids/#{ids}")[:data]
    broker_meta_in_json = JSON.parse(broker_meta)
    brokers << broker_meta_in_json["host"]
  end
  zk.close
  return brokers
end

def getKafkaStatus(bean, kafkaHosts)
  total = 0
  kafkaHosts.each do |host|
    value = `java -jar #{@jmxcmdPath} - #{host}:#{@kafkaPort} '"kafka.server":name="#{bean}",type="BrokerTopicMetrics"' MeanRate 2>&1`
    total += value.split(": ").last.to_f;
  end
  return total.to_i
end

@kafkaHostsHuaBei = get_brokers_from_zk @zookeeperHuaBeiVIP
@kafkaHostsHuaDong = get_brokers_from_zk @zookeeperHuaDongVIP

pointsInHuaBei = []
pointsOutHuaBei = []
pointsMessagesInHuaBei = []

pointsInHuaDong = []
pointsOutHuaDong = []
pointsMessagesInHuaDong = []

pointsInTotal = []
pointsOutTotal = []
pointsMessagesInTotal = []

(1..@numOfPoints).each do |i|
  pointsInHuaBei << { x: i, y: getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaBei) }
  pointsOutHuaBei << { x: i, y: getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaBei) }
  pointsMessagesInHuaBei << { x: i, y: getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaBei) }

  pointsInHuaDong << { x: i, y: getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaDong) }
  pointsOutHuaDong << { x: i, y: getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaDong) }
  pointsMessagesInHuaDong << { x: i, y: getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaDong) }

  pointsInTotal << { x: i, y:  pointsInHuaBei.last.y + pointsInHuaDong.last.y}
  pointsOutTotal << { x: i, y:  pointsOutHuaBei.last.y + pointsOutHuaDong.last.y}
  pointsMessagesInTotal << { x: i, y: pointsMessagesInHuaBei.last.y + pointsMessagesInHuaDong.last.y}
end

last_x = pointsInHuaBei.last[:x]

flag = 0

SCHEDULER.every "#{@period}s", allow_overlapping: false do
  flag += 1
  if 100 == flag
    flag = 0
    @kafkaHostsHuaBei = get_brokers_from_zk @zookeeperHuaBeiVIP
    @kafkaHostsHuaDong = get_brokers_from_zk @zookeeperHuaDongVIP
  end

  pointsInHuaBei.shift
  pointsOutHuaBei.shift
  pointsMessagesInHuaBei.shift

  pointsInHuaDong.shift
  pointsOutHuaDong.shift
  pointsMessagesInHuaDong.shift

  pointsInTotal.shift
  pointsOutTotal.shift
  pointsMessagesInTotal.shift

  last_x += 1

  pointsInHuaBei << { x: i, y: getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaBei) }
  pointsOutHuaBei << { x: i, y: getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaBei) }
  pointsMessagesInHuaBei << { x: i, y: getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaBei) }

  pointsInHuaDong << { x: i, y: getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaDong) }
  pointsOutHuaDong << { x: i, y: getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaDong) }
  pointsMessagesInHuaDong << { x: i, y: getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaDong) }

  pointsInTotal << { x: i, y:  pointsInHuaBei.last.y + pointsInHuaDong.last.y}
  pointsOutTotal << { x: i, y:  pointsOutHuaBei.last.y + pointsOutHuaDong.last.y}
  pointsMessagesInTotal << { x: i, y: pointsMessagesInHuaBei.last.y + pointsMessagesInHuaDong.last.y}

  send_event('bytesInHuaBei', points: pointsInHuaBei)
  send_event('bytesOutHuaBei', points: pointsOutHuaBei)
  send_event('messagesInHuaBei', points: pointsMessagesInHuaBei)

  send_event('bytesInHuaDong', points: pointsInHuaDong)
  send_event('bytesOutHuaDong', points: pointsOutHuaDong)
  send_event('messagesInHuaDong', points: pointsMessagesInHuaDong)

  send_event('bytesInTotal', points: pointsInTotal)
  send_event('bytesOutTotal', points: pointsOutTotal)
  send_event('messagesInTotal', points: pointsMessagesInTotal)
end
