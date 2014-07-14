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
    value = `java -jar #{@jmxcmdPath} - #{host}:#{@kafkaPort} '"kafka.server":name="#{bean}",type="BrokerTopicMetrics"' Count 2>&1`
    total += value.split(": ").last.to_f;
  end
  return total.to_i
end

@kafkaHostsHuaBei = get_brokers_from_zk @zookeeperHuaBeiVIP
@kafkaHostsHuaDong = get_brokers_from_zk @zookeeperHuaDongVIP

lastInHuaBei = 0
lastOutHuaBei = 0
lastMessagsInHuaBei = 0
pointsInHuaBei = []
pointsOutHuaBei = []
pointsMessagesInHuaBei = []

lastInHuaDong = 0
lastOutHuaDong = 0
lastMessagsInHuaDong = 0

pointsInHuaDong = []
pointsOutHuaDong = []
pointsMessagesInHuaDong = []

pointsInTotal = []
pointsOutTotal = []
pointsMessagesInTotal = []

last_x = 0
flag = 0
last_timestamp = time.now() - 3

SCHEDULER.every "#{@period}s", allow_overlapping: false do
  interval = time.now() - last_timestamp
  last_timestamp = time.now()

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

  tmp = getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaBei)
  pointsInHuaBei << { x: last_x, y: (tmp - lastInHuaBei) / interval }
  lastInHuaBei = tmp

  tmp = getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaBei)
  pointsOutHuaBei << { x: last_x, y: (tmp - lastOutHuaBei) / interval }
  lastOutHuaBei = tmp

  tmp = getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaBei)
  pointsMessagesInHuaBei << { x: last_x, y: (tmp - lastMessagesInHuaBei) / interval }
  lastMessagsInHuaBei = tmp

  tmp = getKafkaStatus("AllTopicsBytesInPerSec", @kafkaHostsHuaDong)
  pointsInHuaDong << { x: last_x, y: (tmp - lastInHuaDong) / interval }
  lastInHuaDong = tmp

  tmp = getKafkaStatus("AllTopicsBytesOutPerSec", @kafkaHostsHuaDong)
  pointsOutHuaDong << { x: last_x, y: (tmp - lastOutHuaDong) / interval }
  lastOutHuaDong = tmp

  tmp = getKafkaStatus("AllTopicsMessagesInPerSec", @kafkaHostsHuaDong)
  pointsMessagesInHuaDong << { x: last_x, y: (tmp - lastMessagesInHuaDong) / interval }
  lastMessagsInHuaDong = tmp

  pointsInTotal << { x: last_x, y:  pointsInHuaBei.last[:y] + pointsInHuaDong.last[:y]}
  pointsOutTotal << { x: last_x, y:  pointsOutHuaBei.last[:y] + pointsOutHuaDong.last[:y]}
  pointsMessagesInTotal << { x: last_x, y: pointsMessagesInHuaBei.last[:y] + pointsMessagesInHuaDong.last[:y]}

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
