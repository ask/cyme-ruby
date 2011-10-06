$TESTING=true

require 'fileutils'
require 'rubygems'
require 'spec'

TEST_PATH = File.join(Dir.pwd(), 'REMOVE_ME')


END {
    FileUtils.remove_dir(TEST_PATH, :force => true)
}
