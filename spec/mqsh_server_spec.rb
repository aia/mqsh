require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MQsh::Server" do
	it "should initialize with a config hash" do
		config = {
			"url" => "amqp:/",
			"hostname" => "server1",
			"read_queue" => "write-mqsh",
			"write_exchange" => "read-mqsh",
			"cmd" => ARGV.join(" ")
		}
		
		mqsh_server = MQsh::Server.new(config)
		["url", "hostname", "cmd"].each do |key|
			mqsh_server.instance_variable_get("@#{key}").should == config[key]
		end
	end
end
