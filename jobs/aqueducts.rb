def getCurrentStatus()

  result = {
  :products => 0,
  :services => 0,
  :pv => 0
  }

  require 'rest-client'
  require 'json'

  products_url = "http://api.aqueducts.baidu.com/v1/products/"
  products = JSON.parse(RestClient.get products_url)

  products.each do |product|
    services_url = products_url + product["name"] + "/services/"
    services = JSON.parse(RestClient.get services_url)

    result[:products] += 1 if services.count > 0

    services.each do |service|
      result[:services] += 1;
    end
  end

  return result;
end

points = []
(1..10).each do |i|
  status = getCurrentStatus()
  points << { x: i, y: status[:pv] }
end
last_x = points.last[:x]

current_products = 0
current_services = 0

SCHEDULER.every '5s', allow_overlapping: false do
  points.shift
  last_x += 1
  status = getCurrentStatus()

  last_products = current_products
  last_services = current_services
  current_products = status[:products]
  current_services = status[:services]

  points << { x: last_x, y: status[:pv] }

  send_event('products', {current: current_products, last: last_products})
  send_event('services', {current: current_services, last: last_services})
#  send_event('messagesProcessedPerSecond', points: points)
end
