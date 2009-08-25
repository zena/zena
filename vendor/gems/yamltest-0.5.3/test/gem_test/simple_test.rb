# Simple file to test installed gem

require 'test/unit'
require 'rubygems'
require 'yamltest'

class TestYamltestGem < Test::Unit::TestCase
  yamltest :directory => '.'
  
  def yt_parse(key, source, context)
    source.split(//).reverse.join
  end
  
  yt_make
end