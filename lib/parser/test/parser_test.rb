require File.join(File.dirname(__FILE__) , 'testhelp.rb')
module Zafu
  module Tags
    def r_hello
      'hello world!'
    end
    
    def r_text
      @params[:text]
    end
    
    def r_repeat
      count = @params[:count] || 2
      count.to_i.times do
        out expand_with
      end
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
  testfile :zafu, :zafu_asset, :zafu_insight, :zazen
  def test_single
    do_test('zazen', 'gallery_and_images')
  end
  def test_zazen_image_no_image
    file = 'zazen'
    test = 'image_no_image'
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}", :helper=>ParserModule::DummyHelper.new(@@test_strings[file])).render(:images=>false)
    assert_equal @@test_strings[file][test]['res'], res
  end
  make_tests
end