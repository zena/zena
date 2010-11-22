require 'test_helper'

class KpathTest < Zena::Unit::TestCase
  context 'A class path (kpath)' do
    should 'represent the class hierarchy' do
      assert_equal 'N', Node.kpath
      assert_equal 'NP', Page.kpath
      assert_equal 'U', PagerDummy.ksel
      assert_equal 'NU', PagerDummy.kpath
      assert_equal 'NUS', SubPagerDummy.kpath
    end
  end
end