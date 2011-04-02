require 'thread'

module MQsh
	class Worker
		def initialize(config)
			@url = config["url"]
			@hostname = config["hostname"]
			@read_queue_name = "read-#{@hostname}-#{$$}"
			@read_exchange = config["read_exchange"]
			@write_queue_name = config["write_queue"]
			@pids = {}
			@pids_lock = Mutex.new
		end
		
		def log(*args)
			p [Time.now, *args]
		end
		
		def setup_queues
			AMQP.start(@url)
			Signal.trap('INT') {
				disconnect
				AMQP.stop{ EM.stop }
			}
			Signal.trap('TERM') {
				disconnect
				AMQP.stop{ EM.stop }
			}
			@amq = MQ.new
			@read_queue = @amq.queue(@read_queue_name, :auto_delete => true)
			@write_queue = @amq.queue(@write_queue_name)
		end
		
		def read_queue_action(hdr, msg)
			log @read_queue_name, :received, msg
			res = Marshal.load(msg)
			pp ["type", res[:type]]
			case res[:type]
				when "discovery"
					respond_to_discovery
				when "request"
					run_command(res[:hash], res[:data])
				when "status"
					pp "processing status request"
					get_status(res[:hash])
				when "mkill"
					pp "processing mkill #{res[:data]}"
					process_mkill(res[:data])
			end
		end
		
		def respond_to_discovery
			@write_queue.publish(Marshal.dump({:type => "discovery", :host => @hostname, :data => "pong"}))
		end
		
		def process_mkill(cmd_hash)
			@pids.each do |key,value|
				if (value[:hash].match(cmd_hash.chomp))
					pp ["killing", key, value]
					Process.kill("HUP", key)
				end
			end
		end
		
		def run_command(hash, cmd)
			output = ""
			pio = nil
			command = cmd.chomp
			pp ["command", cmd, command]
			operation = proc do
				pio = IO.popen(command)
				@pids_lock.synchronize {
					@pids[pio.pid] = {}
					@pids[pio.pid][:cmd] = cmd.chomp
					@pids[pio.pid][:hash] = hash.chomp
					pp ["pids", @pids]
				}
				output = pio.read
				pp pio
			end
			
			callback = proc do
				log @write_queue.name, :sending, output
				@pids_lock.synchronize {
					@pids.delete(pio.pid)
				}
				pio.close
				@write_queue.publish(
					Marshal.dump({
						:type => "response",
						:host => @hostname,
						:hash => hash,
						:data => output
					})
				)
			end
			
			EM.defer(operation, callback)
			
			#Previos interaction. EM.system does not process commands that include |, e.g. "ps -ef | grep http"
			#Also need to maintain a list of running commands and have the ability to terminate commands on demand
			#EM.system(cmd) do |output,status| 
			#	if status.exitstatus == 0
			#		log @write_queue.name, :sending, output
			#		@write_queue.publish(
			#			Marshal.dump({
			#				:type => "response",
			#				:host => @hostname,
			#				:hash => hash,
			#				:data => output
			#			})
			#		)
			#	end
			#end
		end
		
		def get_status(hash)
			pp ["pids", @pids]
			res = ""
			@pids.each do |key, value|
				res += "pid: #{key}, cmd: #{value[:cmd]}, hash: #{value[:hash]}\n"
			end
			@write_queue.publish(
				Marshal.dump({
					:type => "status",
					:host => @hostname,
					:hash => hash,
					:data => res
				})
			)
		end
		
		def disconnect
			@write_queue.publish(Marshal.dump({:type => "disconnect", :host => @hostname, :data => "pong"})) 
		end
		
		def start
			EM.run {
				setup_queues
				respond_to_discovery
				@read_queue.bind(@amq.fanout(@read_exchange)).subscribe { |hdr, msg| read_queue_action(hdr, msg) }
			}
		end
	end
end
