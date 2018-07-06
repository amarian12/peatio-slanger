# Peatio Slanger

## Start a local pusher server

    bundle
    bundle exec slanger --app_key foo --secret bar -p dev.key -c dev.crt  -v

## Benchmark

    # connect to pusher compliant server running on localhost with 10 concurrent clients,
    # publish 100 messages to the channel, each with 20 bytes payload.
    ./benchmark.rb -a http://localhost:4567 -w ws://localhost:8080 -i 123 -k foo -s bar -c 10 -n 100 --size 20

## Tips

Increase system limits (linux) with ulimit:

    # check/set your hard/soft limit on file descriptors
    ulimit -Hn
    ulimit -n 4096

    # check/set your hard/soft limit on user processes (threads)
    ulimit -Hu
    ulimit -u 62823

The connection to slanger may fail with a message that app key "foo" does not exist. Alter `app/assets/javascript/lib/pusher_connection.js.coffee`, add `enabledTransports: ['ws', wss']`:

    pusher = new Pusher gon.pusher.key,
      encrypted: gon.pusher.encrypted
      wsHost: gon.pusher.wsHost
      wsPort: gon.pusher.wsPort
      wssPort: gon.pusher.wssPort
      enabledTransports: ['ws', wss']

    window.pusher = pusher
