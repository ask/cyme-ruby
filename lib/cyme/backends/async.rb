require 'eventmachine'
require 'em-http-request'
require 'json'

require 'cyme/backends'
require 'cyme/exceptions'


module Cyme
    module Backends

        class MutableDeferrable < EM::DefaultDeferrable
            attr :state

            def initialize(opts={})
                super()
                @state = PENDING
                unless opts[:proxy_errback].nil?
                    proxy_errback(opts[:proxy_errback])
                end
            end

            def succeed(r=nil)
                @state = SUCCESS
                super(r)
            end

            def fail(r=nil)
                @state = FAILURE
                super(r)
            end

            def ready?
                @state == PENDING
            end

            def default(r)
                self.fail(r) if ready?
            end

            def proxy_errback(other)
                other.errback do |r|
                    self.fail(r)
                end
            end
        end

        class Async

            def request(method, url, data, &block)
                block = block.nil? ? JSON.method(:parse) : block
                req = EventMachine::HttpRequest.new(url)
                if method == 'get'
                    req = req.get(:query => data)
                else
                    req = req.send(method.to_sym, :body => data)
                end

                promise = MutableDeferrable.new(:proxy_errback => req)
                req.callback do
                    status = req.response_header.status
                    if status >= 200 && status < 300
                        promise.succeed(block[req.response])
                    else
                        promise.fail(Cyme::ClientError.from_em_error(req))
                    end
                end

                promise
            end

            def until_timeout(timeout, interval, &block)
                promise = MutableDeferrable.new()
                max_iterations = (timeout / interval).ceil()
                iter = [0]

                cancelled = [false]
                promise.timeout(timeout)

                timer_callback = Proc.new do
                    unless cancelled[0]
                        block[promise]

                        if promise.ready?
                            EventMachine.add_timer(interval, &timer_callback)
                        end
                    end
                end
                EventMachine.add_timer(interval, &timer_callback)

                promise
            end

            def with_promise
                promise = MutableDeferrable.new()
                promise.succeed()

                promise
            end

            def defer(res, &block)
                promise = MutableDeferrable.new()
                res.callback do |response|
                    promise.succeed block[response]
                end

                promise
            end
        end
    end
end
