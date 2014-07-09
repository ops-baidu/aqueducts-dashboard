require 'open-uri'
require "json"

def latency
  url = "http://api.aqueducts.baidu.com/v1/events?product=im&service=router&item=page_view&calculation=count&from=-15s&to=now&detail=true"
  result = JSON.parse(open(url).read)
  last_point = result.first
  insert_time = last_point["insert_time"].to_i / 1000
  event_time = last_point["event_time"].to_i / 1000
  latency = insert_time - event_time
end

points = []
(1..10).each do |i|
  points << { x: i, y: latency }
end
last_x = points.last[:x]

<<<<<<< HEAD
SCHEDULER.every '20s' do
=======
SCHEDULER.every '3s' do
>>>>>>> f4e7eeafddfa9223c79944bf2df6baf806289232
  points.shift
  last_x += 1
  points << { x: last_x, y: latency }

  send_event('latency', points: points)
end
