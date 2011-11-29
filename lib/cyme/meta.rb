# encoding: utf-8

require 'base64'
require 'rubygems'


module Cyme
    VERSION = '0.1.0'

    class Meta

        def initialize()
            @name = 'cyme'
            @version = VERSION.dup
            @authors = ['Ask Solem']
            @platform = Gem::Platform::RUBY
            @has_rdoc = true
            @extra_rdoc_files = ['LICENSE', 'README.md']
            @email = [Base64.decode64('YXNrQGNlbGVyeXByb2plY3Qub3Jn\n')]
            @homepage = 'http://github.com/ask/cyme-ruby'
            @description = @summary = 'Celery Instance Manager client for Ruby'

            # files
            @files = ['LICENSE', 'README.md', 'Rakefile',
                      'lib/cyme/api.rb',
                      'lib/cyme/branch.rb',
                      'lib/cyme/client.rb',
                      'lib/cyme/exceptions.rb',
                      'lib/cyme/meta.rb',
                      'lib/cyme/utils.rb',
                      'spec/spec_helper.rb',
                      'spec/branch_spec.rb']
            @require_paths = ['lib']

            @dependencies = ['rest-client', 'json']

            # RubyForge
            @rubyforge_project = 'cyme'
        end

        def contribute_to_spec(s)
            spec = self.to_h()
            deps = spec.delete('dependencies')
            spec.each { |k,v| s.send("#{k}=", v) }
            deps.collect { |dep| s.add_dependency(dep) }
        end

        def get(k)
            k = k.to_s
            self.instance_variable_get(k[0] == 64 ? k : "@#{k}")
        end

        def to_h
            Hash[*self.instance_variables.map { |k| [k.to_s[1..-1], get(k)] }.flatten(1)]
        end

        def method_missing(attr, *args, &block)
            return get(attr)
        end
    end
end
