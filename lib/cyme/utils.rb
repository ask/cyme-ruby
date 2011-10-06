# encoding: utf-8
require 'pp'
require 'json'


# Like PP::pp but returns String.
def pformat(obj, s=StringIO.new)
    PP.pp(obj, s)
    s.rewind()

    s.read().chomp()
end


def branches_from_cmdline(opts={})
    broker = opts[:broker] || "amqp://"
    cyme = opts[:cyme] || "cyme"

    JSON.parse(%x[#{cyme} -L branches -b #{broker}])
end


class AsyncReader

    def initialize(readable)
        @readable = readable
        @buf = ""
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

        @buf += buf.join("")
        dump() if debug
    end

    def to_s
        @buf
    end

    def dump(out=STDOUT)
        buf, @buf = @buf, ""
        out.write(buf) unless buf.size.zero?
    end
end
