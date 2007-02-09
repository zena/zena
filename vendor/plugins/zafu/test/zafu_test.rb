require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module Zafu
  module Rules
    def hello
      'hello world!'
    end
    
    def test
      self.inspect
    end
  end
end

class ZazenTest < Test::Unit::TestCase
  testfile :zafu
  def test_parse_params
    zafu = Zafu::Block.new("")
    res = zafu.send(:scan_params, "bob='super' life = 'cool' ")
    assert_equal 'super', res[:bob]
    assert_equal 'cool', res[:life]
    res = zafu.send(:scan_params, " bob='super \"joe\"' life ='l\\\'ami' ")
    assert_equal 'super "joe"', res[:bob]
    assert_equal "l'ami", res[:life]
  end
  
  def test_inspect
    zafu = Zafu::Block.new("are <z:test>you</z:test> ok ?")
    assert_equal "[dummy:|]are [test:|]you[/test] ok ?[/dummy]", zafu.inspect
  end
  make_tests
end