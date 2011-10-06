# encoding: utf-8

require 'socket'
require 'fileutils'

require 'cyme/client'
require 'cyme/exceptions'
require 'cyme/utils'

CYME_PORT = 1968
DEFAULT_BROKER = "amqp://guest:guest@localhost:5672//"

module Cyme

# Interface to +cyme-branch+
#
# @param [String] workdir  Working directory (_required_).
# @param [String] :id  The id of the branch, defaults to
#                      +cyme+ + current hostname.
# @param [String] :broker  Broker URL for the master bus (defaults to
#                          +amqp://guest:guest@localhost:5672//+).
# @param [String] :loglevel  Loglevel, can be one of *CRITICAL*/*ERROR*/
#                            *WARNING*/*INFO*/*DEBUG* (defaults to *INFO*).
# @param [Integer] :controllers  Number of controller threads (defaults to 2).
# @param [Integer] :port  Listening port for the HTTP service
#                         (defaults to 1968).
# @param [Boolean] :debug  Output debugging information.
class Branch
    attr :id
    attr :broker
    attr :workdir
    attr :loglevel
    attr :controllers
    attr :port
    attr :detach
    attr :started

    def initialize(workdir, opts={})
        @workdir = File.expand_path(workdir)
        @id = opts[:id] || ["cyme", Socket.gethostname()].join(".")
        @broker = opts[:broker] || DEFAULT_BROKER
        @loglevel = opts[:loglevel] || "INFO"
        @controllers = opts[:controllers] || 2
        @port = opts[:port] || CYME_PORT
        @detach = !opts[:detach].nil? ? opts[:detach] : true
        @DEBUG = !opts[:debug].nil? ? opts[:debug] : ENV["CYME_DEBUG"]
        @started = false
    end

    def client
        Client.new(url)
    end

    def restart(opts={})
        stop(opts.merge(:sig => :TERM))
        start(opts)
    end

    def _fork
        Process.fork() do
            yield
        end
    end

    def _exec(argv)
        exec(*argv)
    end

    def start(opts={})
        out = opts[:out] || STDOUT
        timeout = opts[:timeout] || 30.0
        interval = opts[:interval] || 0.5

        s = Status.new("Starting cyme-branch #@id", out)
        return s.ALREADY_STARTED if responds_to_signal?

        FileUtils.mkdir_p(instances)
        s.step()
        cmd = [cyme_branch] + argv
        out.puts(">>> #{cmd.join(' ')}") if @DEBUG
        read, write = IO.pipe()
        reader = AsyncReader.new(read)
        ppid = fork() do
            STDOUT.reopen(write)
            STDERR.reopen(write)
            _exec(cmd)
        end

        (timeout / interval).ceil.times do
            reader.update(:debug => @DEBUG)
            if is_alive?
                @started = true
                return s.OK(ppid)
            end
            s.step(sleep(interval))
        end

        # show output after timeout
        reader.dump()

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
        Process.kill(sig, pid)
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

    def stop(opts={})
        sig = opts[:sig] || :TERM
        out = opts[:out] || STDOUT
        timeout = opts[:timeout] || 30.0
        interval = opts[:interval] || 0.5

        s = Status.new("Stopping cyme-branch #@id", out)
        return s.NOT_RUNNING unless responds_to_signal?

        (timeout / interval * 5).ceil.times do
            begin
                kill(sig)
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

    def stop!
        stop(:sig => :KILL)
    end

    def path(*args)
        File.join(workdir, *args)
    end

    def cyme_branch
        "cyme-branch"
    end

    def instances(*args)
        path("instances", *args)
    end

    def logfile
        instances("branch.log")
    end

    def pidfile
        instances("branch.pid")
    end

    def pid
        File.read(pidfile()).to_i()
    end

    def addr
        ip = IPSocket.getaddress(Socket.gethostname())
        return ip == '::1' ? '127.0.0.1' : ip
    end

    def url
        "http://#{addr}:#@port/"
    end

    def to_arg(k)
        k.to_s.tr("_", "-")
    end

    def options(opts={}, acc="")
        opts.delete(nil)    # remove possible predicate
        opts.delete(false)
        opts.map { |k, v| v.nil? ? "--#{to_arg k}" : "--#{to_arg k}=#{v}" }
    end

    def argv
        options(:broker => broker,
                :id => @id,
                :sup_interval => 5,
                :instance_dir => instances,
                :pidfile => pidfile,
                :logfile => logfile,
                :loglevel => loglevel,
                detach && :detach => nil) << ":#@port"
    end
end


class Status
    attr :out

    def initialize(msg, out=STDOUT)
        @out = out
        @out.write("* #{msg}...")
    end

    def step(*_)
        @out.write(".")
    end

    def method_missing(msg, *args, &block)
        @out.write(" [#{msg.to_s.upcase}]\n")

        args[0]
    end
end

end  # module
