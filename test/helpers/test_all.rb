require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :basic
  def test_single
    do_test('basic', 'show_tattr')
  end
  make_tests
end