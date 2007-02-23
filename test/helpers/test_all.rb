require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :relations, :basic
  def test_single
    do_test('basic', 'set_in_ztag')
  end
  make_tests
end