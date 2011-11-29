# encoding: utf-8

require 'pp'
require 'json'

module Cyme

    # Like PP#pp but returns String.
    def self.pformat(obj, s=StringIO.new)
        PP.pp(obj, s)
        s.rewind()

        s.read().chomp()
    end

    def self.branches_from_cmdline(opts={})
        broker = opts[:broker] || 'amqp://'
        cmd = opts[:cmd] || 'cyme-list-branches'
        limit = opts[:limit]
        command = "#{cmd} --broker='#{broker}'"
        if limit:
            command = command << " --limit=#{limit}"
        end
        JSON.parse(%x[#{command}])
    end

    class AsyncReader

        def initialize(readable)
            @readable = readable
            @buf = ''
        end

        def update(opts={})
            maxlen = opts[:maxlen] || 0xff
            debug = opts[:debug] || false

            buf = []
            loop do
                begin
                    buf << @readable.read_nonblock(maxlen)
                rescue Errno::EAGAIN
                    break
                end
            end
            return if buf.size.zero?

            @buf += buf.join('')
            dump() if debug
        end

        def to_s
            @buf
        end

        def dump(out=STDOUT)
            buf, @buf = @buf, ''
            out.write(buf) unless buf.size.zero?
        end
    end

end  # Cyme
