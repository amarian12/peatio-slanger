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

    # check your hard limit on file descriptors
    ulimit -Hn

    # set your soft limit to max hard limit (suppose your hard limit is 4096)
    ulimit -n 4096
