require 'json'
require 'restclient'

require 'cyme/backends'
require 'cyme/exceptions'



module Cyme
    module Backends

        class EagerDeferrable
            attr :state

            def initialize
                @state = PENDING
                @result = nil
            end

            def succeed(result=nil)
                @state = SUCCESS
                @result = result
            end

            def fail(result=nil)
                @state = FAILURE
                @result = result
            end

            def callback(&block)
                if @state == SUCCESS
                    block[@result]
                end
            end

            def errback(&block)
                if @state == FAILURE
                    block[@result]
                end
            end
        end


        class Default

            def request(method, url, data, &block)
                block = block.nil? ? JSON.method(:parse) : block
                begin
                    block[RestClient.method(method).call(url, data)]
                rescue RestClient::ExceptionWithResponse => exc:
                    raise Cyme::ClientError.from_restclient_error(exc)
                end
            end

            def after(res, &block)
                block[res]
            end

            def with_promise
                promise = EagerDeferrable.new()
                promise.succeed()

                promise
            end

            def until_timeout(timeout, interval, &block)
                promise = EagerDeferrable.new()

                (timeout / interval).ceil.times do
                    if block[promise]
                        promise.succeed()
                        break
                    else
                        sleep(interval)
                    end
                end

                if promise.state == PENDING
                    promise.fail()
                end

                promise
            end

        end
    end
end
