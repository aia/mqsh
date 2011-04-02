require 'socket'

module MQsh
	class Server
		class Connection < EventMachine::Connection
			attr_accessor :parent, :running_commands, :waiting, :param
			
			def intialize
				#@running_commands = {}
			end
			
			def post_init
				@running_commands = {}
				send_data(">> ")
			end
			
			def unbind
				@parent.connections.delete(@param)
			end
			
			def receive_data(data)
				#puts "Received: #{data}"
				#if (cmd = data.match("/run (.+)"))
				case data
				when %r|^/run (.+)|
					# Add a check to see if there are workers to execute the command
					cmd = $1
					pp ["peer", @param[:port], @param[:ip]]
					command_hash = [Time.now.to_i, @param[:port], cmd].join("-")
					@parent.process_input(command_hash, cmd)
					pp ["command", command_hash, cmd]
					if (@running_commands == nil)
						@running_commands = {}
					end
					@running_commands[command_hash] = true
					pp ["running commands", @running_commands]
					send_data("-- running #{cmd}\n")
				when %r|^/exit|
				#elsif (cmd = data.match("/exit"))
					close_connection
				when %r|^/workers|
				#elsif (cmd = data.match("/workers"))
					workers = @parent.workers.keys.join(" ")
					pp ["workers", @parent.workers]
					#pp ["waiting", @parent.waiting]
					pp ["client-waiting", @waiting]
					send_data("#{workers}\r\n>> ")
				when %r|^/clients|
				#elsif (cmd = data.match("/clients"))
					clients = []
					@parent.connections.each {|conn| clients << [conn[:ip], conn[:port]].join(":") }
					send_data([clients.join("\r\n"), "\r\n>> "].join)
				when %r|^/status|
					cmd = "status"
					pp ["peer", @param[:port], @param[:ip]]
					command_hash = [Time.now.to_i, @param[:port], cmd].join("-")
					@parent.get_status(command_hash)
					pp ["command", command_hash]
					if (@running_commands == nil)
						@running_commands = {}
					end
					@running_commands[command_hash] = true
					pp ["running commands", @running_commands]
					send_data("-- checking status\n")
				when %r|^/mkill (.+)|
					cmd_hash = $1
					pp ["peer", @param[:port], @param[:ip]]
					@parent.send_mkill(cmd_hash)
					send_data("-- sending mkill #{cmd_hash}\n")
					send_data(">> ")
				else
					send_data("command unrecognized\r\n")
					send_data(">> ")
				end
			end
		end
	end
end