require 'fileutils'

CYME_TEST_PATH = File.join(Dir.pwd(), 'REMOVE_ME')
CYME_OUTPUT = StringIO.new()


END {
    if !ENV['SKIP_CLEANUP']
        FileUtils.remove_dir(CYME_TEST_PATH, :force => true)
    end
}
