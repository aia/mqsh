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
		
		def start
			EM.run {
				AMQP.start(@url)
				amq = MQ.new
				@read_queue = amq.queue(@read_queue_name)
				@write_exchange = amq.fanout(@write_exchange_name)
				@write_exchange.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "ping"}))

				EM.add_timer(2) do
					log 'clients-discovered', @clients.join(" ")
					@waiting = Hash[*@clients.zip(@clients).flatten]
					@write_exchange.publish(Marshal.dump({:type => "request", :host => @hostname, :data => @cmd}))
					#waiting = Hash[*clients.zip(clients).flatten]
				end
				#@write_exchange.publish(cmd)
				@read_queue.subscribe do |header, msg|
					#log 'write-dsh', :received, header
					res = Marshal.load(msg)
					if (res[:type] == "discovery") 
						@clients << res[:host]
					elsif (res[:type] == "response")
						res[:data].split("\n").each { |part| puts "#{res[:host]}: #{part}" }
						@waiting.delete(res[:host])
						if (@waiting == {})
							EM.stop_event_loop
						else
							log "waiting for", @waiting.keys.join(" ")
						end
					end
					#EM.stop_event_loop
				end
			}
		end
	end
end