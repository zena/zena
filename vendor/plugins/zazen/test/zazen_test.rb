require File.join(File.dirname(__FILE__) , 'testhelp.rb')

class ZazenTest < Test::Unit::TestCase
  testfile :basic
  
  def test_basic_code_escape
    parser = Zena::Zazen::Parser.new(basic[:code_escape][:in])
    parser.send(:extract_code)
    assert_match %r{ZAZENBLOCKCODE}, parser.text
    parser.send(:render_code)
    assert_equal basic[:code_escape][:out], parser.text
  end
  
  def test_basic_at_escape
    parser = Zena::Zazen::Parser.new(basic[:at_escape][:in])
    parser.send(:extract_code)
    assert_match %r{ZAZENBLOCKAT}, parser.text
    parser.send(:render_code)
    assert_equal basic[:at_escape][:out], parser.text
  end
  
  def test_basic_single_no_image
    assert_equal basic[:single_no_image][:out], render(basic[:single_no_image][:in], :images => false)
  end
  make_tests
end
