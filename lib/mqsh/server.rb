module MQsh
	class Server
		
		def initialize(config)
			@url = config["url"]
			@hostname = config["hostname"]
			@read_queue_name = config["read_queue"]
			@write_exchange_name = config["write_exchange"]
			@cmd = config["cmd"]
			@clients = []
			@waiting = []
		end
		
		def log(*args)
			p [Time.now, *args]
		end
		
		def setup_queues
			AMQP.start(@url)
			amq = MQ.new
			@read_queue = amq.queue(@read_queue_name)
			@write_exchange = amq.fanout(@write_exchange_name)
		end
		
		def read_queue_action(hdr, msg)
			res = Marshal.load(msg)
			case res[:type]
			when "discovery"
				@clients << res[:host]
			when "response"
				res[:data].split("\n").each { |part| puts "#{res[:host]}: #{part}" }
				@waiting.delete(res[:host])
				if (@waiting == {})
					EM.stop_event_loop
				else
					log "waiting for", @waiting.keys.join(" ")
				end
			end
		end
		
		def initiate_discovery
			@write_exchange.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "ping"}))
			
			EM.add_timer(2) do
				log 'clients-discovered', @clients.join(" ")
				@waiting = Hash[*@clients.zip(@clients).flatten]
				@write_exchange.publish(Marshal.dump({:type => "request", :host => @hostname, :data => @cmd}))
				#waiting = Hash[*clients.zip(clients).flatten]
			end
		end
		
		def start
			EM.run {
				setup_queues
				initiate_discovery
				
				@read_queue.subscribe { |hdr, msg| read_queue_action(hdr, msg) }
			}
		end
	end
end