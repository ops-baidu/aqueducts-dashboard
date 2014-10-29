require 'time'

# last_send_time = Time.now.to_i

def send_warning(message)
    # if ( (Time.now.to_i - @last_send_time) > 300 and Time.now.strftime("%H%M") != "0000" )
    if Time.now.strftime("%H%M") != "0000"
      cmd = 'gsmsend -s emp01.baidu.com:15003 -s emp02.baidu.com:15003 g_oped_jiuze@"' + message + '"'
      system cmd
#      @last_send_time = Time.now.to_i
    end
end

def check_elasticsearch(url)
  begin
    require 'rest-client'
    #response = RestClient.get "http://10.36.4.246:8200/_cluster/health"
    response = RestClient.get "#{url}/_cluster/health"
    ret = JSON.parse(response)
    return ret['status']
  rescue Exception
    return "red"
  end
    return "red"
end

def check_zookeeper(bns)
  begin
    #zookeeper_hosts = `get_instance_by_service zookeeper.aqueducts.all`.split
    zookeeper_hosts = `get_instance_by_service #{bns}`.split

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

def check_search(url, area)
  begin
    start = Time.now
    require 'rest-client'
    #response = RestClient.get "http://api.aqueducts.baidu.com/v1/events?product=im&service=router&item=page_view&calculation=count&from=-1m&to=now"
    response = RestClient.get "#{url}"
    if response.code != 200 
       send_warning "[#{Time.now.to_s}][#{area}] online search error: not 200"
       return false
    end

    ret = JSON.parse(response)
    if ret.size == 0
      send_warning "[#{Time.now.to_s}][#{area}] online search error: result is empty array"
      return false
    end
    response_time = Time.now - start
    if response_time > 5
      send_warning "[#{TIme.now.to_s}][#{area}][X-runtime #{response.headers[:x_runtime]}] online search error: search response time #{response_time}" 
      return false
    end
  rescue Exception
    send_warning "[#{Time.now.to_s}][#{area}]online search error: search exception"
    return false
  end
  return true
end

SCHEDULER.every '10s', :first_in => 0 do |job|

  #===========================================================
  # HuaBei
    statuses = Array.new

   # elasticsearch service status
   color = check_elasticsearch 'http://10.36.4.246:8200'
   if color != "green"
     arrow = "icon-warning-sign icon-2x"
   else
     arrow = "icon-ok-sign icon-2x"
   end
   statuses.push({label: "elasticsearch", arrow: arrow, color: color})

    # zookeeper service status
    if check_zookeeper 'zookeeper.aqueducts.bj'
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
        arrow = "icon-warning-sign icon-2x"
        color = "red"
    end
    statuses.push({label: "zookeeper", arrow: arrow, color: color})

    # search service usable
    if check_search('http://api.aqueducts.baidu.com/v1/events?product=sf&service=bfe&item=page_view&calculation=count&from=-10s&to=now', 'HB')
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
    send_event('serviceStatusHuaBei', {items: statuses})
  #===========================================================
  # HuaDong
    statuses.clear

   # elasticsearch service status
   color = check_elasticsearch 'http://10.202.6.12:8200'
   if color != "green"
     arrow = "icon-warning-sign icon-2x"
   else
     arrow = "icon-ok-sign icon-2x"
   end
   statuses.push({label: "elasticsearch", arrow: arrow, color: color})

    # zookeeper service status
    if check_zookeeper 'zookeeper.aqueducts.sh01'
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
        arrow = "icon-warning-sign icon-2x"
        color = "red"
    end
    statuses.push({label: "zookeeper", arrow: arrow, color: color})

    # search service usable
    if check_search('http://api.aqueducts.baidu.com/v1/events?product=sf&service=bfe&item=page_view&calculation=count&from=-10s&to=now&area=HD', 'HD')
        arrow = "icon-ok-sign icon-2x"
        color = "green"
    else
# 	send_warning "online search found error"
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
    send_event('serviceStatusHuaDong', {items: statuses})
  #===========================================================
end
