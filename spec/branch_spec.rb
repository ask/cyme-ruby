require File.join(File.dirname(__FILE__), 'spec_helper')

require 'cyme/branch'


class MockBranch < Cyme::Branch
    attr_accessor :forks
    attr_accessor :execs
    attr_accessor :responds_to_signal

    def initialize(*args)
        super(TEST_PATH, *args)
        @forks = 0
        @execs = 0
        @responds_to_signal = false
    end

    def is_alive?
        true
    end

    def responds_to_signal?
        @responds_to_signal
    end

    def pid
        Process.pid()
    end

    def _fork
        @forks += 1
    end

    def _exec(argv)
        @execs += 1
    end
end


describe Cyme::Branch do

    describe "States" do

        it "should detach by default" do
            MockBranch.new().detach.should == true
        end

        it "should be alive after started" do
            b = MockBranch.new()
            b.start()
            b.started.should == true
        end

        it "should not start if already started" do
            b = MockBranch.new()
            b.responds_to_signal = true
            b.start()
            b.started.should == false
        end

    end
end

