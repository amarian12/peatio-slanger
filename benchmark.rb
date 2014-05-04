#!/usr/bin/env ruby

require 'pusher'
require 'pusher-client'

if ARGV.size != 6
  puts "Usage: #{$0} app_id app_key app_secret number_of_clients number_of_messages payload_size"
  exit 1
end

id     = ARGV[0]
key    = ARGV[1]
secret = ARGV[2]
num    = ARGV[3].to_i
total  = ARGV[4].to_i
size   = ARGV[5].to_i

PusherClient.logger = Logger.new File.open('pusher_client.log', 'w')

channels = num.times.map do |i|
  received_total = 0
  socket = PusherClient::Socket.new(key)
  socket.connect(true)
  socket.subscribe('benchmark')
  socket['benchmark'].bind('bm_event') do |data|
    received_total += 1
    puts "#{i+1}.#{received_total}: #{data}"
  end
  socket['benchmark']
end
sleep 0.5 until channels.all?(&:subscribed)

Pusher.app_id = id
Pusher.key    = key
Pusher.secret = secret

count = 0
while count < total
  count += 1
  payload = { time: Time.now, id: count, data: '*'*size }
  Pusher.trigger_async('benchmark', 'bm_event', payload)
  sleep 1
end

Signal.trap('INT')  { exit 0 }
Signal.trap('TERM') { exit 0 }
loop do
  sleep 1
end
