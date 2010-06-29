require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'active_support'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'shoulda_macros'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'data2pdf'
require 'shoulda_data2pdf'

class Test::Unit::TestCase


  def assert_exist file
    File.delete file if File.exist? file
    yield
    assert File.exist?(file), "#{file} does not exist"
    File.delete file if File.exist? file
  end

end
