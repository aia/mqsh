#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'mqsh'
require 'pp'

config = {
	"url" => "amqp:/",
	"hostname" => ARGV[0],
	"read_exchange" => "read-mqsh",
	"write_queue" => "write-mqsh"
}

mqsh_client = MQsh::Client.new(config)

pp mqsh_client

mqsh_client.start