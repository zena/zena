require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :relations, :basic
  def test_single
    do_test('basic', 'ignore')
  end
  make_tests
end