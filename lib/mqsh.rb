require 'rubygems'
require 'amqp'

#require 'mqsh/config'
require 'mqsh/server'
require 'mqsh/client'

module MQsh
	extend self
	
	attr_reader :config
	
	@config = {}
	
	def load(hash)
		@config = hash
	end
end