require 'json'
require 'cgi'
require 'pp'

require 'restclient'

module Cyme


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

    def initialize(code=500, error=nil, traceback="")
        @code = code
        @error = error || "INTERNAL SERVER ERROR"
        @traceback = traceback
    end

    def to_s()
        "NOK #{@code}: #{@error}\n#{@traceback}"
    end

    # create instance from RestClient::ExceptionWithResponse instance.
    def self.from_error(exc)
        code, body = exc.http_code, exc.http_body
        if code == 404
            return new code, "NOT FOUND", body
        end
        if body.include? "nok"
            error, traceback = JSON.parse(exc.http_body)["nok"]
            new code, error, traceback
        else
            new code, nil, body
        end
    end
end


# Cyme HTTP API Client.
#
# @param [String] url  Base URL to Cyme branch.
# @param [flag] debug If enabled debugging information is printed to STDOUT.
#
# -- Examples
#
# @example Create client instance.
#
#    >> client = Cyme::Client.new("http://localhost:1968")
#    >> client = Cyme::Client.new("http://localhost:1968", debug=True)
#
# @example Create application named +foo+, with default broker
#
#    >> app = client.add("foo", "amqp://guest:guest@localhost:5672//")
#
# @example Get an existing application named +foo+.
#
#    >> app = client.get("foo")
#
# @example Create new instance in app +foo+.
#
#    >> instance = app.instances.add()
#    <Instance: "38bbc04e-8780-4805-a260-705392d99e49">
#    >> instance.name
#    "38bbc04e-8780-4805-a260-705392d99e49"
#
#    >> instance = app.instances.get("38bbc04e-8780-4805-a260-705392d99e49")
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
#    >> app.queues.add("myqueue", :exchange => "ex",
#                                 :exchange_type => "direct",
#                                 :routing_key => "key")
#    <Queue: "myqueue">
#
#    >> app.queues.get("myqueue")
#    ...
#
# @example Make our new instance consume from +myqueue+.
#
#    >> instance.consumers.add("myqueue")
#    {"ok": "ok"}
#
# @example Get a list of queues instance is consuming from
#
#    >> instance.consumers.all()
#
# @example Make instance cancel consuming from +myqueue+.
#
#    >> instance.consumers.cancel("myqueue")
#
# @example Delete instance.
#
#    >> instance.delete()
#
# @example Delete queue.
#
#    >> app.queues.get("myqueue").delete()
#
# @example Delete application.
#
#    >> app.delete()
#
class Client
    attr :url

    def initialize(url, debug=nil)
        @url = url.chomp("/")
        @DEBUG = !debug.nil? ? debug : ENV["CYME_DEBUG"]
    end

    # create new app.
    #
    # @param [String] broker URL of default broker used for this app.
    #
    def add(name, broker="amqp://guest:guest@localhost:5672//")
        App.new(self, POST({"broker" => broker}, *[name]))
    end

    # get list of all apps.
    def all()
        all_names.map { |name| get(name) }
    end

    # get list of all app names.
    def all_names()
        GET()
    end

    # get app by name.
    def get(name)
        App.new(self, GET({}, *[name]))
    end

    # delete app by name.
    def delete(name)
        DELETE({}, *[name])
    end

    # @returns true if branch server is alive.
    def ping?
        begin
            GET({}, *["ping"])["ok"] == "pong"
        rescue Errno::ECONNREFUSED
            return false
        end
    end

    # @private
    def GET(data={}, *path)
        request(:method=>:GET, :data=>data, *path)
    end

    # @private
    def POST(data={}, *path)
        request(:method=>:POST, :data=>data, *path)
    end

    # @private
    def PUT(data={}, *path)
        request(:method=>:PUT, :data=>data, *path)
    end

    # @private
    def DELETE(data={}, *path)
        request(:method=>:DELETE, :data=>data, *path)
    end

    # @private
    def request(options={}, *path)
        method = options[:method]
        url = ([@url] + path).join("/").chomp("/") + "/"
        puts("-> #{method} #{url} #{pformat options[:data]}") if @DEBUG
        begin
            JSON.parse(
                RestClient.method(method.to_s.downcase).call(url,
                                                             options[:data]))
        rescue RestClient::ExceptionWithResponse => exc:
            raise ClientError.from_error(exc)
        end
    end
end

# Base class for API subsections.
class Section
    attr :parent

    def initialize(parent, attrs={})
        @parent = parent
        attrs.each do |k, v|
            self.instance_variable_set("@#{k}", v)
        end
    end

    def GET(data={}, *path)
        parent.GET(data, *base + path)
    end

    def PUT(data={}, *path)
        parent.POST(data, *base + path)
    end

    def POST(data={}, *path)
        parent.POST(data, *base + path)
    end

    def DELETE(data={}, *path)
        parent.DELETE(data, *base + path)
    end

    def inspect()
        self.to_s
    end

end


# Base class for sections that return instances.
class ModelSection < Section

    def all()
        all_names.map { |name| get(name) }
    end

    def all_names()
        GET()
    end

    def get(name)
        model.new(self, GET({}, *[name]))
    end

    def add(name, opts={})
        model.new(self, POST(opts, *[name]))
    end

    def delete(name)
        DELETE({}, *[name])
    end

end


# The App type.
class App < Section
    attr :name
    attr :broker

    def delete()
        parent.delete(name)
    end

    def instances()
        Instances.new(self)
    end

    def queues()
        Queues.new(self)
    end

    def base()
        [name]
    end

    def to_s()
        "<App: #{name} #{broker}"
    end

end


# +app.instances+ section.
class Instances < ModelSection

    def add(name=nil, opts={})
        super
    end

    def model()
        Instance
    end

    def base()
        ["instances"]
    end
end

# The Instance type.
class Instance < Section
    attr :name
    attr :broker
    attr :pool
    attr :min_concurrency
    attr :max_concurrency
    attr :is_enabled
    attr :queues

    def delete()
        DELETE()
    end

    def consumers()
        Consumers.new(self)
    end

    def stats()
        GET({}, ["stats"])
    end

    def autoscale(max=nil, min=nil)
        POST({"max" => max, "min" => min}, ["autoscale"])
    end

    def to_s()
        "<Instance: #{name}>"
    end

    def base()
        [name]
    end
end


# +instance.consumers+ section.
class Consumers < Section

    def all()
        GET()
    end

    def all_names()
        all.keys()
    end

    def add(name, opts={})
        POST(opts, *[name])
    end

    def delete(name)
        DELETE({}, *[name])
    end

    def cancel(name)
        delete(name)
    end

    def base()
        ["queues"]
    end

end


# +app.queues+ section.
class Queues < ModelSection

    def model()
        Q
    end

    def base()
        ["queues"]
    end
end


# the Queue type.
class Q < Section
    attr :name
    attr :exchange
    attr :exchange_type
    attr :routing_key
    attr :options

    def delete()
        DELETE()
    end

    def to_s()
        "<Queue: #{name}>"
    end

    def base()
        [name]
    end
end


# Like PP::pp but returns String.
def pformat(obj, s=StringIO.new)
    PP.pp(obj, s)
    s.rewind()
    s.read().chomp()
end

end  # module
