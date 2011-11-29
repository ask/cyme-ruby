# encoding: utf-8


module Cyme

    module Backends
        PENDING = 0
        SUCCESS = 1
        FAILURE = 2
    end

    module SynRole

        def after(res, &block)
            @backend.after(res, &block)
        end

        def with_promise
            @backend.with_promise()
        end

        def until_timeout(timeout, interval, &block)
            @backend.until_timeout(timeout, interval, &block)
        end

    end

    def self.instantiate(s, *args)
        require File.join(s.downcase.split('::'))

        s.split('::').inject(Kernel) { |s, n| s.const_get(n) }.new(*args)
    end

    def self.get_backend(backend=nil, prefix="Cyme::Backends", sep='::')
        backend ||= 'default'

        if backend.kind_of? String
            if backend.index(sep).nil?
                backend = [prefix, backend.capitalize()].join(sep)
            end
            return instantiate(backend)
        end

        backend
    end

end
