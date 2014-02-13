require 'open-uri'
require "json"

def latency
  url = "http://api.aqueducts.baidu.com/v1/events?product=im&service=router&item=page_view&calculation=count&from=-5s&to=now"
  result = JSON.parse(open(url).read)
  last_point = result.first
  latency = Time.parse(last_point["insert_time"]) - Time.parse(last_point["event_time"])
end

points = []
(1..10).each do |i|
  points << { x: i, y: latency }
end
last_x = points.last[:x]

SCHEDULER.every '20s' do
  points.shift
  last_x += 1
  points << { x: last_x, y: latency }

  send_event('latency', points: points)
end
