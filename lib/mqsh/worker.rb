module MQsh
	class Worker
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
		
		def setup_queues
			AMQP.start(@url)
			@amq = MQ.new
			@read_queue = @amq.queue(@read_queue_name, :auto_delete => true)
			@write_queue = @amq.queue(@write_queue_name)
		end
		
		def read_queue_action(hdr, msg)
			log @read_queue_name, :received, msg
			res = Marshal.load(msg)
			case res[:type]
				when "discovery"
					respond_to_discovery
				when "request"
					run_command(res[:data])
			end
		end
		
		def respond_to_discovery
			@write_queue.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "pong"}))
		end
		
		def run_command(cmd)
			EM.system(cmd) do |output,status| 
				if status.exitstatus == 0
					log @write_queue.name, :sending, output
					@write_queue.publish(Marshal.dump({:type => "response", :host => @hostname, :data => output}))
				end
			end
		end
		
		def start
			EM.run {
				setup_queues
				@read_queue.bind(@amq.fanout(@read_exchange)).subscribe { |hdr, msg| read_queue_action(hdr, msg) }
			}
		end
	end
end