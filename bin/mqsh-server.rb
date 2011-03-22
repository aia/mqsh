#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'pp'
require 'mqsh'


config = {
	"url" => "amqp:/",
	"hostname" => "server1",
	"read_queue" => "write-mqsh",
	"write_exchange" => "read-mqsh",
	"cmd" => ARGV.join(" ")
}

mqsh_server = MQsh::Server.new(config)

pp mqsh_server

mqsh_server.start