require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module Zafu
  module TestRules
    def z_hello
      'hello world!'
    end
    
    def z_set_context
      expand_with(@params)
    end
    
    def z_missing
      return unless check_params(:good, :night)
      "nothing missing"
    end
  end
  module OtherTestRules
    def z_hello
      'hello mom!'
    end
  end
end
class ZazenTest < Test::Unit::TestCase
  testfile :zafu, :zafu_asset, :zena
  def test_parse_params
    zafu = Zafu::Parser.new("")
    res = zafu.send(:scan_params, "bob='super' life = 'cool' ")
    assert_equal 'super', res[:bob]
    assert_equal 'cool', res[:life]
    res = zafu.send(:scan_params, " bob='super \"joe\"' life ='l\\\'ami' ")
    assert_equal 'super "joe"', res[:bob]
    assert_equal "l'ami", res[:life]
  end
  
  def test_inspect
    zafu = Zafu::Parser.new("are <z:test>you</z:test> ok ?")
    assert_equal "[zafu:|]are [test:|]you[/test] ok ?[/zafu]", zafu.inspect
  end
  
  def test_new_with_url
    strings = @@test_strings['zafu']
    parser = Zafu.parser_with_rules(Zafu::TestRules).new_with_url('/default/menu', DummyHelper.new(strings))
    assert_equal strings[:default_menu][:out], parser.render
  end
  
  def test_two_parsers
    parser1 = Zafu.parser_with_rules(Zafu::TestRules)
    parser2 = Zafu.parser_with_rules(Zafu::OtherTestRules)
    assert_equal 'I say "hello world!"', parser1.new('I say "<z:hello/>"').render
    assert_equal 'I say "hello mom!"', parser2.new('I say "<z:hello/>"').render
  end
  # def test_single
  #   strings = @@test_strings['zafu_tag']
  #   test = :zafu_keep_params
  #   assert_equal strings[test][:out], do_test(strings, test)
  # end
    
  
  make_tests
end