require File.dirname(__FILE__) + '/../test_helper'

class CacheTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_create_cache
    i = 1
    assert_equal "content 1", Cache.with(1,[2,3,4],'first', 'test')  { "content #{i}" }
    i = 2
    assert_equal "content 1", Cache.with(1,[2,3,4],'first', 'test')  { "content #{i}" }
    
    Cache.sweep(:user_id=>1)
    
    assert_equal "content 2", Cache.with(1,[2,3,4],'first', 'test')  { "content #{i}" }
    i = 3
    assert_equal "content 3", Cache.with(1,[2,3,4],'second', 'test') { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4],'first' , 'test') { "content #{i}" }
    assert_equal "content 3", Cache.with(2,[3,8]  ,'first' , 'test') { "content #{i}" }
    i = 4
    Cache.sweep(:group_ids=>[7,2])
    assert_equal "content 4", Cache.with(1,[2,3,4],'second', 'test') { "content #{i}" }
    assert_equal "content 4", Cache.with(1,[2,3,4],'first' , 'test') { "content #{i}" }
    assert_equal "content 3", Cache.with(2,[3,8]  ,'first' , 'test') { "content #{i}" }
    i = 5
    Cache.sweep(:group_ids=>[8])
    assert_equal "content 4", Cache.with(1,[2,3,4],'second', 'test') { "content #{i}" }
    assert_equal "content 4", Cache.with(1,[2,3,4],'first' , 'test') { "content #{i}" }
    assert_equal "content 5", Cache.with(2,[3,8]  ,'first' , 'test') { "content #{i}" }
    i = 6
    Cache.sweep(:context=>['first', 'test'])
    assert_equal "content 4", Cache.with(1,[2,3,4],'second', 'test') { "content #{i}" }
    assert_equal "content 6", Cache.with(1,[2,3,4],'first' , 'test') { "content #{i}" }
    assert_equal "content 6", Cache.with(2,[3,8]  ,'first' , 'test') { "content #{i}" }
  end
end
