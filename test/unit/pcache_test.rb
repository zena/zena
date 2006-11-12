require File.dirname(__FILE__) + '/../test_helper'

class PcacheTest < Test::Unit::TestCase
  include ZenaTestUnit
   
  def test_cache_for
    assert_nil Pcache.cache_for(default_hash)
    assert Pcache.cache_content('Hello', default_hash)
    assert_equal 'Hello', Pcache.cache_for(default_hash)
    assert_nil Pcache.cache_for(default_hash.merge({:visitor_id=>3}))
    assert Pcache.expire_cache(:visitor_id=>4)
    assert_nil Pcache.cache_for(default_hash)
  end
  private
  def default_hash
    { :visitor_id=>4, :visitor_groups=>[1,2,4], :lang=>'en', :plug=>:menu, :context=>[] }
  end
end
