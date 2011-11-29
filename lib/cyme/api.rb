# encoding: utf-(8

require 'cyme/backends'
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

            def after(res, &block)
                parent.after(res, &block)
            end

            def inspect
                self.to_s
            end

        end

        # Base class for sections that return instances.
        class ModelSection < Subsection

            def all
                after(all_names) do |names|
                    names.map { |name| get(name) }
                end
            end

            def all_names
                after(GET()) { |res| res }
            end

            def get(name)
                res = GET({}, *[name])
                after(res) do |res|
                    model.new(self, res)
                end
            end

            def add(name, opts={})
                res = POST(opts, *[name])
                after(res) do |res|
                    model.new(self, res)
                end
            end

            def delete(name)
                res = DELETE({}, *[name])
                after(res) { |res| res }
            end
        end

        class RootSection < ModelSection
            attr :url
            attr :backend

            include Cyme::SynRole

            def initialize(url, opts={})
                @parent = nil
                @url = url.chomp('/')
                @DEBUG = opts[:debug].nil? ? ENV['CYME_DEBUG'] : opts[:debug]
                @backend = Cyme.get_backend(opts[:backend])
            end

            def instantiate(s, *args)
                if s.index('::').nil?
                    return instantiate("Cyme::Backends::#{s}", *args)
                end
                require File.join(s.downcase.split('::'))
                s.split('::').inject(Kernel) { |s, n| s.const_get(n) }.new(*args)
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
                url = ([@url] + path).join('/').chomp('/') + '/'
                if @DEBUG
                    puts("-> #{method} #{url} #{options[:data]}")
                end
                @backend.request(method.to_s.downcase, url, options[:data])
            end
        end

        # The App type.
        class App < Subsection
            attr_accessor :name
            attr_accessor :broker

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
                super(nil, opts)
            end

            def model
                Instance
            end

            def base
                ['instances']
            end
        end

        # The Instance type.
        class Instance < Subsection
            attr_accessor :name
            attr_accessor :broker
            attr_accessor :pool
            attr_accessor :min_concurrency
            attr_accessor :max_concurrency
            attr_accessor :is_enabled
            attr_accessor :queues

            def delete
                DELETE()
            end

            def consumers
                Consumers.new(self)
            end

            def stats
                GET({}, ['stats'])
            end

            def autoscale(max=nil, min=nil)
                POST({'max' => max, 'min' => min}, ['autoscale'])
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
                ['queues']
            end
        end

        # +app.queues+ section.
        class Queues < ModelSection

            def model
                Q
            end

            def base
                ['queues']
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

    end  # Cyme::API
end  # Cyme
