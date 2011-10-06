# encoding: utf-(8

require 'json'
require 'restclient'
require 'cyme/exceptions'

module Cyme
module API

    # Base class for API subsections.
    class Subsection
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

        def inspect
            self.to_s
        end

    end


    # Base class for sections that return instances.
    class ModelSection < Subsection

        def all
            all_names.map { |name| get(name) }
        end

        def all_names
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

    class RootSection < ModelSection
        attr :url

        def initialize(url, debug=nil)
            @parent = nil
            @url = url.chomp("/")
            @DEBUG = debug.nil? ? ENV["CYME_DEBUG"] : debug
        end

        def GET(data={}, *path)
            request(:method=>:GET, :data=>data, *path)
        end

        def POST(data={}, *path)
            request(:method=>:POST, :data=>data, *path)
        end

        def PUT(data={}, *path)
            request(:method=>:PUT, :data=>data, *path)
        end

        def DELETE(data={}, *path)
            request(:method=>:DELETE, :data=>data, *path)
        end

        def request(options={}, *path)
            method = options[:method]
            url = ([@url] + path).join("/").chomp("/") + "/"
            puts("-> #{method} #{url} #{pformat options[:data]}") if @DEBUG
            begin
                JSON.parse(RestClient.method(
                    method.to_s.downcase).call(url, options[:data]))
            rescue RestClient::ExceptionWithResponse => exc:
                raise ClientError.from_error(exc)
            end
        end
    end


    # The App type.
    class App < Subsection
        attr :name
        attr :broker

        def delete
            parent.delete(name)
        end

        def instances
            Instances.new(self)
        end

        def queues
            Queues.new(self)
        end

        def base
            [name]
        end

        def to_s
            "<App: #@name #@broker>"
        end
    end


    # +app.instances+ section.
    class Instances < ModelSection

        def add(name=nil, opts={})
            super()
        end

        def model
            Instance
        end

        def base
            ["instances"]
        end
    end

    # The Instance type.
    class Instance < Subsection
        attr :name
        attr :broker
        attr :pool
        attr :min_concurrency
        attr :max_concurrency
        attr :is_enabled
        attr :queues

        def delete
            DELETE()
        end

        def consumers
            Consumers.new(self)
        end

        def stats
            GET({}, ["stats"])
        end

        def autoscale(max=nil, min=nil)
            POST({"max" => max, "min" => min}, ["autoscale"])
        end

        def to_s
            "<Instance: #@name>"
        end

        def base
            [name]
        end
    end


    # +instance.consumers+ section.
    class Consumers < Subsection

        def all
            GET()
        end

        def all_names
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

        def base
            ["queues"]
        end
    end


    # +app.queues+ section.
    class Queues < ModelSection

        def model
            Q
        end

        def base
            ["queues"]
        end
    end


    # the Queue type.
    class Q < Subsection
        attr :name
        attr :exchange
        attr :exchange_type
        attr :routing_key
        attr :options

        def delete
            DELETE()
        end

        def to_s
            "<Queue: #@name>"
        end

        def base
            [name]
        end
    end

end  # Cyme::API::
end  # Cyme::
