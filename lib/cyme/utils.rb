# encoding: utf-8
require 'pp'


# Like PP::pp but returns String.
def pformat(obj, s=StringIO.new)
    PP.pp(obj, s)
    s.rewind()
    s.read().chomp()
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
        while 1
            begin
                buf << @readable.read_nonblock(maxlen)
            rescue Errno::EAGAIN
                break
            end
        end
        return if buf.length.zero?

        @buf += buf.join("")
        dump() if debug
    end

    def to_s()
        @buf
    end

    def dump(out=STDOUT)
        buf, @buf = @buf, ""
        out.write(buf) if !buf.length.zero?
    end
end
