require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :basic
  def test_single
    do_test('basic', 'each_traductions')
  end
  make_tests
end