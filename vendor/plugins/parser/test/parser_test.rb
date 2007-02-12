require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module ParserRules
  module Zafu
    def r_hello
      'hello world!'
    end
    
    def r_set_context
      expand_with(@params)
    end
    
    def r_missing
      return unless check_params(:good, :night)
      "nothing missing"
    end
    def r_test
      self.inspect
    end
  end
end
class ZazenTest < Test::Unit::TestCase
  testfile :zafu, :zafu_asset, :zafu_insight
  # testfile :zazen
  
  # def test_parse_params
  #   zafu = Zafu::Parser.new("")
  #   res = zafu.send(:scan_params, "bob='super' life = 'cool' ")
  #   assert_equal 'super', res[:bob]
  #   assert_equal 'cool', res[:life]
  #   res = zafu.send(:scan_params, " bob='super \"joe\"' life ='l\\\'ami' ")
  #   assert_equal 'super "joe"', res[:bob]
  #   assert_equal "l'ami", res[:life]
  # end
  # 
  # def test_inspect
  #   zafu = Zafu::Parser.new("are <z:test>you</z:test> ok ?")
  #   assert_equal "[zafu:|]are [test:|]you[/test] ok ?[/zafu]", zafu.inspect
  # end
  # 
  # def test_new_with_url
  #   strings = @@test_strings['zafu']
  #   parser = Zafu.parser_with_rules(Zafu::TestRules).new_with_url('/default/menu', DummyHelper.new(strings))
  #   assert_equal strings[:default_menu][:out], parser.render
  # end
  # 
  # def test_two_parsers
  #   parser1 = Zafu.parser_with_rules(Zafu::TestRules)
  #   parser2 = Zafu.parser_with_rules(Zafu::OtherTestRules)
  #   assert_equal 'I say "hello world!"', parser1.new('I say "<z:hello/>"').render
  #   assert_equal 'I say "hello mom!"', parser2.new('I say "<z:hello/>"').render
  # end
  # def test_single
  #   file = 'zafu_insight'
  #   test = :with_sub_tags
  #   assert_equal eval("#{file}[test][:out]"), do_test(file, test)
  # end
    
  # def test_zazen_image_no_image
  #   @@test_parsers['zazen'].new_with_url("/benchmark", DummyHelper.new(@@test_strings['zazen'])).render
  #   assert true
  # end
  # 
  # def test_zazen_benchmark
  #   parser = @@test_parsers['zazen']
  #   helper = DummyHelper.new
  #   txt = zazen[:benchmark][:in]
  #   50.times do 
  #     parser.new(txt, :helper=>helper).render
  #   end
  # end
  # 
  def test_zafu_benchmark
    parser = @@test_parsers['zafu']
    helper = DummyHelper.new(@@test_strings['zafu'])
    txt = zafu[:benchmark][:in]
    0.times do 
      parser.new(txt, :helper=>helper).render
    end
  end
  make_tests
end