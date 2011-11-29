# encoding: utf-8

require 'socket'
require 'fileutils'

require 'cyme/backends'
require 'cyme/client'
require 'cyme/exceptions'
require 'cyme/utils'


module Cyme
    BRANCH_PATH = "cyme-branch"
    PORT = 1968
    DEFAULT_BROKER = 'amqp://guest:guest@localhost:5672//'

    # Interface to +cyme-branch+
    #
    # @param [String] workdir  Working directory (_required_).
    # @param [String] :id  The id of the branch, defaults to
    #                      +cyme+ + current hostname.
    # @param [String] :broker  Broker URL for the master bus (defaults to
    #                          +amqp://guest:guest@localhost:5672//+).
    # @param [String] :loglevel  Loglevel, can be one of *CRITICAL*/*ERROR*/
    #                            *WARNING*/*INFO*/*DEBUG* (defaults to *INFO*).
    # @param [Integer] :controllers  Number of controller threads
    #                                (defaults to 2).
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
        attr :branch_path
        attr :backend

        include SynRole

        def initialize(workdir, opts={})
            @workdir = File.expand_path(workdir)
            @id = opts[:id] || Socket.gethostname()
            @broker = opts[:broker] || DEFAULT_BROKER
            @loglevel = opts[:loglevel] || 'INFO'
            @controllers = opts[:controllers] || 2
            @port = opts[:port] || PORT
            @detach = !opts[:detach].nil? ? opts[:detach] : true
            @DEBUG = !opts[:debug].nil? ? opts[:debug] : ENV['CYME_DEBUG']
            @default_out = opts[:out] || STDOUT
            @branch_path = opts[:branch_path] || BRANCH_PATH
            @backend = Cyme.get_backend(opts[:backend])
            @started = false
        end

        def client
            Client.new(url, :backend => @backend)
        end

        def start(opts={})
            out = opts[:out] || @default_out
            timeout = opts[:timeout] || 30.0
            interval = opts[:interval] || 0.5

            s = Status.new("Starting cyme-branch #@id", out)
            if responds_to_signal?
                s.ALREADY_STARTED()
                return with_promise
            end

            FileUtils.mkdir_p(instances)
            s.step()
            cmd = [branch_path] + argv
            out.puts(">>> #{cmd.join(' ')}") if @DEBUG
            read, write = IO.pipe()
            reader = AsyncReader.new(read)
            ppid = fork() do
                STDOUT.reopen(write)
                STDERR.reopen(write)
                _exec(cmd)
            end

            promise = until_timeout(timeout, interval) do |promise|
                reader.update(:debug => @DEBUG)
                s.step()

                if responds_to_signal?
                    after(is_alive?) do
                        promise.succeed true
                    end
                end
            end

            promise.callback do
                s.OK(ppid)
                @started = true
            end

            promise.errback do
                # show output after timeout
                reader.dump()

                # Kill the processes we created so we don't leave a mess.
                s.TIMEOUT(ppid)
                begin
                    Process.kill(:KILL, ppid)
                    stop!
                rescue Errno::ENOENT, Errno::ESRCH
                end

                raise TimeoutError.new(timeout, ppid)
            end

            promise
        end

        def stop(opts={})
            sig = opts[:sig] || :TERM
            out = opts[:out] || @default_out
            timeout = opts[:timeout] || 30.0
            interval = opts[:interval] || 0.5

            s = Status.new("Stopping cyme-branch #@id", out)
            unless responds_to_signal?
                s.NOT_RUNNING()
                return with_promise
            end

            promise = until_timeout(timeout, interval) do |promise|
                begin
                    kill(sig)
                    _responds_to_signal?
                    s.step()
                rescue Errno::ENOENT, Errno::ESRCH
                    promise.succeed()
                end
            end

            promise.callback do
                sig.to_sym == :KILL ? s.KILLED() : s.OK()
            end

            promise.errback do
                s.TIMEOUT kill(:KILL)
            end

            promise
        end

        def stop!
            stop(:sig => :KILL)
        end

        def restart(opts={})
            stop(opts.merge(:sig => :TERM)).callback do
                start(opts)
            end
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

        def path(*args)
            File.join(workdir, *args)
        end

        def instances(*args)
            path('instances', *args)
        end

        def logfile
            instances('branch.log')
        end

        def pidfile
            instances('branch.pid')
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
            k.to_s.tr('_', '-')
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

        private
        def _fork
            Process.fork() do
                yield
            end
        end

        private
        def _exec(argv)
            exec(*argv)
        end

        private
        def kill(sig)
            Process.kill(sig, pid)
        end

        private
        def _responds_to_signal?
            kill(0)
        end
    end


    class Status
        attr :out

        def initialize(msg, out=STDOUT)
            @out = out
            @out.write("* #{msg}...")
        end

        def step(*_)
            @out.write('.')
        end

        def method_missing(msg, *args, &block)
            @out.write(" [#{msg.to_s.upcase}]\n")

            args[0]
        end
    end

end  # Cyme
