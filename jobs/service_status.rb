def check_zookeeper
  begin
    zookeeper_hosts = `get_instance_by_service zookeeper.aqueducts.all`.split

    alive = 0
    zookeeper_hosts.each { |host|
    	alive += ('imok' == `echo ruok | nc #{host} 2181`) ? 1 : 0
    }
    
    return true if alive == zookeeper_hosts.count
  rescue Exception
    return false
  end
  return false
end

def check_search
  begin
    require 'rest-client'
    response = RestClient.get "http://api.aqueducts.baidu.com/v1/ping"
    ret = JSON.parse(response)
    return true if ret['ping'] == "pong"
  rescue Exception
    return false
  end
  return false
end

SCHEDULER.every '20s', :first_in => 0 do |job|

    statuses = Array.new

    # zookeeper service status
    if check_zookeeper
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
        arrow = "icon-warning-sign icon-2x"
        color = "red"
    end
    statuses.push({label: "zookeeper", arrow: arrow, color: color})

    # search service usable
    if check_search
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
        arrow = "icon-warning-sign icon-2x"
        color = "red"
    end
    statuses.push({label: "search", arrow: arrow, color: color})

    # check kafka & storm
    ret = `ssh yf-aqueducts-chart00.yf01 /home/work/tmp/astream_monitor/gen-rb/count_check.rb`

    if ret == "status:YES\n"
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
        arrow = "icon-warning-sign icon-2x"
        color = "red"
    end
    statuses.push({label: "kafka_strom", arrow: arrow, color: color})

    # print statuses to dashboard
    send_event('service_status', {items: statuses})
end
