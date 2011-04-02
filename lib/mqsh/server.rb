module MQsh
	class Server
		attr_accessor :connections, :workers
		
		def initialize(config)
			@url = config["url"]
			@hostname = config["hostname"]
			@listener = {}
			@listener["host"] = config["listener_host"]
			@listener["port"] = config["listener_port"]
			@read_queue_name = config["read_queue"]
			@write_exchange_name = config["write_exchange"]
			@cmd = config["cmd"]
			@workers = {}
			@connections = []
		end
		
		def log(*args)
			p [Time.now, *args]
		end
		
		def setup_queues
			AMQP.start(@url)
			Signal.trap('INT') { AMQP.stop{ EM.stop } }
			Signal.trap('TERM') { AMQP.stop{ EM.stop } }
			amq = MQ.new
			@read_queue = amq.queue(@read_queue_name)
			@write_exchange = amq.fanout(@write_exchange_name)
		end
		
		def start_listener
			EM.start_server(@listener["host"], @listener["port"], MQsh::Server::Connection) do |conn|
				conn.parent = self
				conn.param = {}
				conn.param[:port], conn.param[:ip] = Socket.unpack_sockaddr_in(conn.get_peername)
				conn.param[:ds] = conn 
				@connections << conn.param
			end
			log "listener started"
			log "active connections", @connections
		end
		
		def process_input(hash, data)
			# Add a check if running the command on an empty set
			puts "Received command: #{data}"
			@write_exchange.publish(
				Marshal.dump({
					:type => "request",
					:host => @hostname,
					:hash => hash,
					:data => data
				})
			)
		end
		
		def get_status(hash)
			puts "Received status request: #{hash}"
			@write_exchange.publish(
				Marshal.dump({
					:type => "status",
					:host => @hostname,
					:hash => hash,
					:data => "status"
				})
			)
		end
		
		def send_mkill(cmd_hash)
			puts "Sending mkill: #{cmd_hash}"
			@write_exchange.publish(
				Marshal.dump({
					:type => "mkill",
					:host => @hostname,
					:data => cmd_hash
				})
			)
		end
		
		def route_response(res)
			@connections.each do |conn|
				if (conn[:ds].running_commands[res[:hash]] == nil)
					next
				end
				pp ["waiting", conn[:ds].waiting]
				if (conn[:ds].waiting == nil)
					conn[:ds].waiting = @workers.clone
				end
				res[:data].split("\n").each do |part|
					puts "#{res[:host]}: #{part}"
					conn[:ds].send_data("#{res[:host]}: #{part}\r\n")
				end
				conn[:ds].waiting.delete(res[:host])
				if (conn[:ds].waiting == {})
					conn[:ds].running_commands.delete(res[:hash])
					conn[:ds].send_data(">> ")
					conn[:ds].waiting = nil
				end
			end
		end
		
		def read_queue_action(hdr, msg)
			res = Marshal.load(msg)
			case res[:type]
			when "discovery"
				#if (@waiting[res[:host]] == nil)
				if (@workers[res[:host]] == nil)
					pp ["connected", res[:host]]
					#@workers << res[:host]
					#@waiting[res[:host]] = res[:host]
					@workers[res[:host]] = res[:host]
				end
			when "disconnect"
				pp ["disconnected", res[:host]]
				@workers.delete(res[:host])
				@connections.each do |conn|
					if ((conn[:ds].waiting != nil) && (conn[:ds].waiting[:res] != nil))
						conn[:ds].waiting.delete(res[:host])
					end
				end
			when "status"
				pp ["status", res]
				route_response(res)
			when "response"
				pp ["response", res]
				route_response(res)
			end
		end
		
		def initiate_discovery
			@workers = {}
			
			@write_exchange.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "ping"}))
			
			EM.add_timer(2) do
				pp ['workers-discovered', @workers]
			end
		end
		
		def start
			EM.run {
				setup_queues
				start_listener
				initiate_discovery
				
				EM.add_periodic_timer(300) { initiate_discovery }
				
				@read_queue.subscribe { |hdr, msg| read_queue_action(hdr, msg) }
			}
		end
	end
end
