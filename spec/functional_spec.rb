require File.join(File.dirname(__FILE__), 'spec_helper')
require 'guid'
require 'cyme/branch'

module Cyme; module Funtests; end; end

IDENT = 'CxYxMxE-'
BRANCH = Cyme::Branch.new(CYME_TEST_PATH, :out => CYME_OUTPUT)
COUNTER = [0]


def new_instance_name
    COUNTER[0] += 1
    "#{IDENT}-#{COUNTER[0]}"
end


END {
    c = BRANCH.client()
    c.all() do |app|
        app.instances.all() do |instance|
            instance.delete()
        end
        app.delete()
    end
    BRANCH.stop()
    BRANCH.stop!
    %x[ps auxww | awk '/#{IDENT}/ {print $2}' | xargs kill -9 1>/dev/null 2>&1]
}

describe Cyme::Funtests do

    before(:all) do
        @b = BRANCH
        @b.start()
    end

    describe 'Client' do

        it 'can create/delete applications, instances and queues' do
            c = @b.client
            app_name = Guid.new.to_s()
            foo = c.add(app_name)
            foo.name.should_not be_empty
            c.get(app_name).name.should == foo.name

            foo.instances.all().should be_empty

            i = foo.instances.add(new_instance_name())
            foo.instances.all().should_not be_empty
            i.name.should be_true
            foo.instances.get(i.name).name.should == i.name

            i.autoscale(10, 9)
            scaling = i.autoscale()
            scaling['max'].should == 10
            scaling['min'].should == 9

            i.delete()
            foo.instances.all().should be_empty
        end
    end

    describe 'States' do

        it 'should be alive after start' do
            @b.is_alive?.should be_true
            @b.pid().should > 0
        end

        it 'should prepare argv from instance variables' do
            x = @b
            argv = x.argv().join(' ')
            argv.should =~ /--detach/
            argv.should =~ /--loglevel=INFO/
            x.detach.should be_true

            x = Cyme::Branch.new(CYME_TEST_PATH, :detach   => false,
                                                 :loglevel => "DEBUG")
            argv = x.argv().join(' ')
            x.detach.should be_false
            argv.should_not =~ /--detach/
            argv.should =~ /--loglevel=DEBUG/
        end

        it 'should have an URL' do
            @b.url.should be_true
            @b.url.should =~ /:#{@b.port}/
        end
    end
end
