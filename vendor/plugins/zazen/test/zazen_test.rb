require File.join(File.dirname(__FILE__) , 'testhelp.rb')

class ZazenTest < Test::Unit::TestCase
  testfile :zena
  
  def test_zena_code_escape
    parser = Zazen::Parser.new(zena[:code_escape][:in])
    parser.send(:extract_code)
    assert_match %r{ZAZENBLOCKCODE}, parser.text
    parser.send(:render_code)
    assert_equal zena[:code_escape][:out], parser.text
  end
  
  def test_zena_at_escape
    parser = Zazen::Parser.new(zena[:at_escape][:in])
    parser.send(:extract_code)
    assert_match %r{ZAZENBLOCKAT}, parser.text
    parser.send(:render_code)
    assert_equal zena[:at_escape][:out], parser.text
  end
  
  def test_zena_image_no_image
    assert_equal zena[:image_no_image][:out], render(zena[:image_no_image][:in], :images => false)
  end
  make_tests
end