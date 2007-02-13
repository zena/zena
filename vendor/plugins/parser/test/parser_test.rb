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
  testfile :zafu, :zafu_asset, :zafu_insight, :zafu_zena

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