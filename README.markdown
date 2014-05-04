# Peatio Slanger

## Start a local pusher server

    bundle
    bundle exec slanger --app_key foo --secret bar -p dev.key -c dev.crt  -v

## Benchmark

    # send 10 messages to 1000 concurrent clients, each message includes
    # a 20 bytes payload.
    ./benchmark.rb app_id app_key app_secret 1000 10 20

## Tips

Increase system limits (linux) with ulimit:

    # check your hard limit on file descriptors
    ulimit -Hn

    # set your soft limit to max hard limit (suppose your hard limit is 4096)
    ulimit -n 4096
