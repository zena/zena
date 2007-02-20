require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module Zafu
  module Tags
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
  def test_single
    do_test('zafu', 'html_zafu_comment')
  end
  make_tests
end