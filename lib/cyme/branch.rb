require 'socket'
require 'fileutils'

require 'cyme/client'

CYME_PORT = 1968
DEFAULT_BROKER = "amqp://guest:guest@localhost:5672//"

module Cyme


class TimeoutError < Exception
    attr :timeout
    attr :ppid

    def initialize(timeout, ppid)
        @timeout = timeout
        @ppid = ppid
    end

    def to_s
        "timeout after #{@timeout}s (ppid=#{@ppid})"
    end
end


class Branch
    attr :id
    attr :broker
    attr :workdir
    attr :loglevel
    attr :controllers
    attr :port

    def initialize(workdir, id=nil, broker=nil, loglevel="INFO",
                   controllers=2, port=nil, debug=nil)
        @id = id || ["cyme", Socket.gethostname()].join(".")
        @broker = broker || DEFAULT_BROKER
        @workdir = File.expand_path(workdir)
        @loglevel = loglevel
        @controllers = controllers
        @port = port || CYME_PORT
        @DEBUG = !debug.nil? ? debug : ENV["CYME_DEBUG"]
    end

    def client()
        Client.new(url())
    end

    def restart(out=STDOUT, timeout=30.0, interval=0.5)
        stop("TERM", out, timeout, interval)
        start(out, timeout, interval)
    end

    def start(out=STDOUT, timeout=30.0, interval=0.5)
        s = Status.new "Starting cyme-branch #{@id}", out
        return s.ALREADY_STARTED if responds_to_signal?

        FileUtils.mkdir_p(instances())
        s.step
        cmd = [cyme_branch()] + argv()
        out.puts(">>> #{cmd.join(' ')}") if @DEBUG
        read, write = IO.pipe()
        ppid = Process.fork() do
            STDOUT.reopen(write)
            STDERR.reopen(write)
            exec(*cmd)
        end

        (timeout / interval).ceil.times do
            return s.OK(ppid) if is_alive?
            s.step(sleep(interval))
        end

        # Kill the processes we created so we don't leave a mess.
        s.TIMEOUT(ppid)
        begin
            Process.kill("KILL", ppid)
            stop!
        rescue Errno::ENOENT, Errno::ESRCH
        end

        raise TimeoutError.new(timeout, ppid)
    end

    def kill(sig)
        Process.kill(sig, pid())
    end

    def _responds_to_signal?
        kill(0)
    end

    def responds_to_signal?
        begin
            _responds_to_signal?
        rescue Errno::ENOENT, Errno::ESRCH
            return false
        end
        return true
    end

    def responds_to_ping?
        client.ping?
    end

    def is_alive?
        responds_to_signal? && responds_to_ping?
    end

    def stop(sig="TERM", out=STDOUT, timeout=30.0, interval=0.5)
        s = Status.new "Stopping cyme-branch #{@id}", out
        return s.NOT_RUNNING if !responds_to_signal?

        (timeout / interval * 5).ceil.times do
            begin
                kill sig
                5.times do
                    _responds_to_signal?
                    sleep(interval)
                    s.step()
                end
            rescue Errno::ENOENT, Errno::ESRCH
                return sig == "KILL" ? s.KILLED : s.OK
            end
        end
        return s.TIMEOUT kill("KILL")
    end

    def stop!()
        stop("KILL")
    end

    def path(*args)
        File.join(@workdir, *args)
    end

    def cyme_branch()
        "cyme-branch"
    end

    def instances(*args)
        path("instances", *args)
    end

    def logfile()
        instances("branch.log")
    end

    def pidfile()
        instances("branch.pid")
    end

    def pid()
        File.read(pidfile()).to_i
    end

    def addr()
        ip = IPSocket.getaddress(Socket.gethostname())
        return ip == '::1' ? '127.0.0.1' : ip
    end

    def url()
        "http://#{addr()}:#{@port}/"
    end

    def argv()
        %W{--broker=#{@broker}
           --id=#{@id}
           --detach
           --sup-interval=5
           --instance-dir=#{instances}
           --pidfile=#{pidfile()}
           --logfile=#{logfile()}
           --loglevel=#{@loglevel}
           :#{@port}
        }
    end
end


class Status
    attr :out

    def initialize(msg, out=STDOUT)
        @out = out
        start(msg)
    end

    def start(msg)
        @out.write("* #{msg}...")
        true
    end

    def step(*_)
        @out.write(".")
    end

    def done(msg, ret=true)
        @out.write(" [#{msg}]\n")
        ret
    end

    def OK(ret=true)
        done "OK", ret
    end

    def TIMEOUT(ret=true)
        done "TIMEOUT", ret
    end

    def ALREADY_STARTED(ret=true)
        done "ALREADY_STARTED", ret
    end

    def NOT_RUNNING(ret=true)
        done "NOT_RUNNING", ret
    end

    def KILLED(ret=true)
        done "KILLED", ret
    end
end

end  # module
