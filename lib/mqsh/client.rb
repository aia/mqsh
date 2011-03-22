module MQsh
	class Client
		def initialize(config)
			@url = config["url"]
			@hostname = config["hostname"]
			@read_queue_name = "read-#{@hostname}-#{$$}"
			@read_exchange = config["read_exchange"]
			@write_queue_name = config["write_queue"]
		end
		
		def log(*args)
			p [Time.now, *args]
		end
		
		def read_action(msg)
			log @read_queue_name, :received, msg
			res = Marshal.load(msg)
			if (res[:type] == "discovery")
				@write_queue.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "pong"}))
			elsif (res[:type] == "request")
				EM.system(res[:data]) do |output,status| 
					if status.exitstatus == 0
						log @write_queue, :sending, output
						@write_queue.publish(Marshal.dump({:type => "response", :host => @hostname, :data => output}))
					end
				end
			end
		end
		
		def start
			EM.run {
				AMQP.start(@url)
				@amq = MQ.new
				@read_queue = @amq.queue(@read_queue_name, :auto_delete => true)
				@write_queue = @amq.queue(@write_queue_name)
				@read_queue.bind(@amq.fanout(@read_exchange)).subscribe { |msg| 
					read_action(msg) 
				}
			}
		end
	end
end