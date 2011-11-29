require File.join(File.dirname(__FILE__), 'spec_helper')

require 'em-spec/rspec'

require 'cyme/client'
require 'cyme/backends/default'
require 'cyme/backends/async'
require 'cyme/utils'


describe Cyme::Backends do

    it 'should have a default' do
        client = Cyme::Client.new('http://localhost:1968')
        client.backend.should be_kind_of Cyme::Backends::Default
    end

    it 'should accept string alias' do
        client = Cyme::Client.new('http://localhost:1968', :backend => 'async')
        client.backend.should be_kind_of Cyme::Backends::Async
    end

    it 'should accept string' do
        client = Cyme::Client.new('http://localhost:1968',
                                  :backend => "Cyme::Backends::Async")
        client.backend.should be_kind_of Cyme::Backends::Async
    end

    it 'should accept instance' do
        backend = Cyme::Backends::Async.new()
        client = Cyme::Client.new('http://localhost:1968', :backend => backend)
        client.backend.should be backend
    end

    describe Cyme::Backends::Async do
        include EM::SpecHelper

        it 'should return deferrable' do
            em do
                client = Cyme::Client.new('http://google.com',
                                          :backend => 'async')
                r = client.backend.request(
                        'get', 'http://www.ntnu.no/', {}) { |r| r }
                r.should be_kind_of EM::DefaultDeferrable
                r.callback do |data|
                    data.should_not be_empty
                    done
                end
                r.errback { |r| raise "-GUARD- #{Cyme.pformat r}" }
            end
        end
    end
end
