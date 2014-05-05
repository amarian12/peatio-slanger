#!/usr/bin/env ruby

require 'pusher'
require 'pusher-client'
require 'json'
require 'uri'
require 'optparse'

options = {
  api_uri: 'http://api.pusherapp.com:80',
  ws_uri:  'ws://ws.pusherapp.com:80',
  num: 1,
  messages: 10,
  payload_size: 20,
  send_rate: 10
}

OptionParser.new do |opts|
  opts.on '-c', '--concurrency NUMBER', 'Number of clients' do |k|
    options[:num] = k.to_i
  end

  opts.on '-n', '--messages NUMBER', 'Number of messages' do |k|
    options[:messages] = k.to_i
  end

  opts.on '-i', '--app_id APP_ID', "Pusher application id" do |k|
    options[:app_id] = k
  end

  opts.on '-k', '--app_key APP_KEY', "Pusher application key" do |k|
    options[:app_key] = k
  end

  opts.on '-s', '--secret SECRET', "Pusher application secret" do |k|
    options[:app_secret] = k
  end

  opts.on '-a', '--api_uri URI', "API service uri (Default: http://api.pusherapp.com:80)" do |uri|
    options[:api_uri] = URI(uri)
  end

  opts.on '-w', '--websocket_uri URI', "WebSocket service uri (Default: ws://ws.pusherapp.com:80)" do |uri|
    options[:ws_uri] = URI(uri)
  end

  opts.on '--size NUMBER', 'Payload size in bytes. (Default: 20)' do |s|
    options[:payload_size] = s.to_i
  end

  opts.on '--send-rate NUMBER', 'Message publish rate.  (Default: 10)' do |r|
    options[:send_rate] = r.to_i
  end

  opts.on '--subscribe', 'Only subscribe.' do |s|
    options[:subscribe] = true
  end

  opts.on '--publish', 'Only publish.' do |s|
    options[:publish] = true
  end
end.parse!

unless options[:app_id] && options[:app_key] && options[:app_secret]
  puts "You must provide all of app ID, key, secret, run #{$0} -h for more help."
  exit 1
end

PusherClient.logger = Logger.new File.open('pusher_client.log', 'w')

stats = Hash.new {|h, k| h[k] = []}

def puts_summary(stats, num, total, size, send_rate, total_elapsed=nil)
  latencies = stats.values.flatten
  latency_avg = latencies.inject(&:+) / latencies.size
  latency_mid = latencies.sort[latencies.size/2]

  puts "\n*** Summary (clients: #{num}, messages total/rate: #{total}/#{send_rate}, payload size: #{size})***\n"
  puts "Message received: %d (%.2f%%)" % [latencies.size, latencies.size.to_f*100/(num*total)]
  puts "Total time: #{total_elapsed}s" if total_elapsed
  puts "avg latency: #{latency_avg}s"
  puts "min latency: #{latencies.min}s"
  puts "max latency: #{latencies.max}s"
  puts "mid latency: #{latency_mid}"
end

unless options[:publish]
  sockets = options[:num].times.map do |i|
    sleep 0.1
    received_total = 0
    socket = PusherClient::Socket.new(
      options[:app_key],
      ws_host: options[:ws_uri].host,
      ws_port: options[:ws_uri].port,
      wss_port: options[:ws_uri].port,
      encrypted: options[:ws_uri].scheme == 'wss'
    )
    socket.connect(true)
    socket.subscribe('benchmark')
    socket['benchmark'].bind('bm_event') do |data|
      payload = JSON.parse data
      latency = Time.now.to_f - payload['time'].to_f
      stats[i] << latency

      received_total += 1
      puts "[#{i+1}.#{received_total}] #{data[0,60]}"

      socket.disconnect if received_total == options[:messages]
    end

    socket
  end

  channels = sockets.map {|s| s['benchmark'] }
  sleep 0.5 until channels.all?(&:subscribed)
end

on_signal = ->(s) { puts_summary(stats, options[:num], options[:messages], options[:payload_size], options[:send_rate]); exit 0 }
Signal.trap('INT',  &on_signal)
Signal.trap('TERM', &on_signal)

Pusher.app_id = options[:app_id]
Pusher.key    = options[:app_key]
Pusher.secret = options[:app_secret]
Pusher.scheme = options[:api_uri].scheme
Pusher.host   = options[:api_uri].host
Pusher.port   = options[:api_uri].port

ts = Time.now

unless options[:subscribe]
  count = 0
  sleep_time = 1.0/options[:send_rate]
  while count < options[:messages]
    count += 1
    payload = { time: Time.now.to_f.to_s, id: count, data: '*'*options[:payload_size] }
    Pusher.trigger_async('benchmark', 'bm_event', payload)
    sleep sleep_time
  end
end

unless options[:publish]
  threads = sockets.map {|s| s.instance_variable_get('@connection_thread') }
  threads.each(&:join)
end

te = Time.now

puts_summary(stats, options[:num], options[:messages], options[:payload_size], options[:send_rate], te-ts) unless options[:publish]
