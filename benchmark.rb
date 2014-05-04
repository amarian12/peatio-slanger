#!/usr/bin/env ruby

require 'pusher'
require 'pusher-client'
require 'json'
require 'uri'

if ARGV.size != 8
  puts "Usage: #{$0} api_server ws_server app_id app_key app_secret number_of_clients number_of_messages payload_size"
  exit 1
end

api_server = URI(ARGV[0])
ws_server  = URI(ARGV[1])
id         = ARGV[2]
key        = ARGV[3]
secret     = ARGV[4]
num        = ARGV[5].to_i
total      = ARGV[6].to_i
size       = ARGV[7].to_i

PusherClient.logger = Logger.new File.open('pusher_client.log', 'w')

stats = Hash.new {|h, k| h[k] = []}

def puts_summary(stats, num, total, size, total_elapsed=nil)
  latencies = stats.values.flatten
  latency_avg = latencies.inject(&:+) / latencies.size
  latency_mid = latencies.sort[latencies.size/2]

  puts "\n*** Summary (clients: #{num}, messagen send: #{total}, payload size: #{size})***\n"
  puts "Message received: %d (%.2f%%)" % [latencies.size, latencies.size.to_f*100/(num*total)]
  puts "Total time: #{total_elapsed}s" if total_elapsed
  puts "avg latency: #{latency_avg}s"
  puts "min latency: #{latencies.min}s"
  puts "max latency: #{latencies.max}s"
  puts "mid latency: #{latency_mid}"
end

sockets = num.times.map do |i|
  sleep 0.2
  received_total = 0
  socket = PusherClient::Socket.new(
    key,
    ws_host: ws_server.host,
    ws_port: ws_server.port,
    wss_port: ws_server.port,
    encrypted: ws_server.scheme == 'wss'
  )
  socket.connect(true)
  socket.subscribe('benchmark')
  socket['benchmark'].bind('bm_event') do |data|
    payload = JSON.parse data
    latency = Time.now.to_f - payload['time'].to_f
    stats[i] << latency

    received_total += 1
    puts "[#{i+1}.#{received_total}] #{data[0,60]}"

    socket.disconnect if received_total == total
  end

  socket
end

channels = sockets.map {|s| s['benchmark'] }
sleep 0.5 until channels.all?(&:subscribed)

on_signal = ->(s) { puts_summary(stats, num, total, size); exit 0 }
Signal.trap('INT',  &on_signal)
Signal.trap('TERM', &on_signal)

Pusher.app_id = id
Pusher.key    = key
Pusher.secret = secret
Pusher.scheme = api_server.scheme
Pusher.host   = api_server.host
Pusher.port   = api_server.port

ts = Time.now
count = 0
while count < total
  count += 1
  payload = { time: Time.now.to_f.to_s, id: count, data: '*'*size }
  Pusher.trigger_async('benchmark', 'bm_event', payload)
  sleep 0.5
end

threads = sockets.map {|s| s.instance_variable_get('@connection_thread') }
threads.each(&:join)
te = Time.now

puts_summary(stats, num, total, size, te-ts)
