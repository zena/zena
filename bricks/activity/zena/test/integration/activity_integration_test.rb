require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class ActivityIntegrationTest < Zena::Integration::TestCase

  context 'A visitor' do
    setup do
      $_test_site = 'test.host'
    end

    context 'with normal access' do
      setup do
        post 'http://test.host/session', :login=>'ant', :password=>'ant'
        assert_redirected_to 'http://test.host/oo'
      end

      should 'not set seen_at on login' do
        assert_equal nil, users(:ant).seen_at
      end
      
      should 'set seen_at on get' do
        before = Time.now.utc.to_i
        get 'http://test.host/oo'
        after = Time.now.utc.to_i
        seen_at = users(:ant).seen_at.to_i
        assert (before <= seen_at) && (seen_at <= after)
      end
    end # with normal access
  end # a visitor
end