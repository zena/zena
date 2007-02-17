require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :basic
  def test_single
    do_test('basic', 'simple_each')
  end
  make_tests
end