# encding: utf-8

require 'cyme/api'


module Cyme
    # Cyme HTTP API Client.
    #
    # @param [String] url  Base URL to Cyme branch.
    # @param [Boolean] debug If enabled debugging information
    #                  is printed to STDOUT.
    #
    # -- Examples
    #
    # @example Create client instance.
    #
    #    >> client = Cyme::Client.new('http://localhost:1968')
    #    >> client = Cyme::Client.new('http://localhost:1968', debug=True)
    #
    # @example Create application named +foo+, with default broker
    #
    #    >> app = client.add('foo', 'amqp://guest:guest@localhost:5672//')
    #
    # @example Get an existing application named +foo+.
    #
    #    >> app = client.get('foo')
    #
    # @example Create new instance in app +foo+.
    #
    #    >> instance = app.instances.add()
    #    <Instance: '38bbc04e-8780-4805-a260-705392d99e49'>
    #    >> instance.name
    #    '38bbc04e-8780-4805-a260-705392d99e49'
    #
    #    >> instance = app.instances.get(
    #    ?>     '38bbc04e-8780-4805-a260-705392d99e49')
    #
    # @example Get instance statistics
    #
    #    >> instance.stats()
    #    {...}
    #
    # @example Change instance concurrency settings.
    #
    #    >> instance.autoscale(max=10, min=10)
    #    {:max => 10, :min => 10}
    #
    # @example Get all instances associated with app +foo+.
    #
    #    >> app.instances.all()
    #    [...]
    #
    # @example Create new queue +myqueue+.
    #
    #    >> app.queues.add('myqueue', :exchange => 'ex',
    #                                 :exchange_type => 'direct',
    #                                 :routing_key => 'key')
    #    <Queue: 'myqueue'>
    #
    #    >> app.queues.get('myqueue')
    #    ...
    #
    # @example Make our new instance consume from +myqueue+.
    #
    #    >> instance.consumers.add('myqueue')
    #    {'ok': 'ok'}
    #
    # @example Get a list of queues instance is consuming from
    #
    #    >> instance.consumers.all()
    #
    # @example Make instance cancel consuming from +myqueue+.
    #
    #    >> instance.consumers.cancel('myqueue')
    #
    # @example Delete instance.
    #
    #    >> instance.delete()
    #
    # @example Delete queue.
    #
    #    >> app.queues.get('myqueue').delete()
    #
    # @example Delete application.
    #
    #    >> app.delete()
    #
    class Client < Cyme::API::RootSection

        def model
            Cyme::API::App
        end

        # create new app.
        #
        # @param [String] broker URL of default broker used for this app.
        #
        def add(name, broker='amqp://guest:guest@localhost:5672//')
            super(name, :broker => broker)
        end

        # @returns true if branch server is alive.
        def ping?
            promise = GET({}, *['ping'])
            after(promise) do |res|
                res['ok'] == 'pong'
            end
        end

        def branches
            GET({}, *['branches'])
        end

        def branch_info(id)
            GET({}, *['branches', id])
        end
    end

end  # Cyme
