# encoding: utf-8

require 'json'


module Cyme

    class TimeoutError < Exception
        attr :timeout
        attr :ppid

        def initialize(timeout, ppid)
            @timeout = timeout
            @ppid = ppid
        end

        def to_s
            "timeout after #{timeout}s (ppid=#@ppid)"
        end
    end

    # Error raised for erroneous HTTP responses.
    #
    # @param [Integer] code The HTTP status code.
    # @param [String] error Description of the error occurred.
    # @param [String] traceback The original Python traceback from the server.
    #
    class ClientError < Exception
        attr :code
        attr :error
        attr :traceback

        def initialize(code=500, error=nil, traceback='')
            @code = code
            @error = error || 'INTERNAL SERVER ERROR'
            @traceback = traceback
        end

        def to_s
            "NOK #@code: #@error\n#@traceback"
        end

        def self.from_error(code, body)
            if code == 404
                return new code, 'NOT FOUND', body
            end
            if body.include? 'nok'
                error, traceback = JSON.parse(exc.http_body)['nok']
                new code, error, traceback
            else
                new code, nil, body
            end
        end

        # create instance from RestClient::ExceptionWithResponse instance.
        def self.from_restclient_error(exc)
            self.from_error(exc.http_code, exc.http_body)
        end

        def self.from_em_error(req)
            self.from_error(req.response_header.status, req.response)
        end
    end

end  # Cyme
