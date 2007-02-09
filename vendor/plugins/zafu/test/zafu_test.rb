require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module Zafu
  module Rules
    def hello
      'hello world!'
    end
    
    def test
      self.inspect
    end
    
    def context
      expand_with(@params)
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
    assert_equal "[zafu:|]are [test:|]you[/test] ok ?[/zafu]", zafu.inspect
  end
  
  def test_new_with_url
    strings = @@test_strings['zafu']
    parser = Zafu::Parser.new_with_url('/default/menu', DummyHelper.new(strings))
    assert_equal strings[:default_menu][:out], parser.render
  end
  make_tests
end