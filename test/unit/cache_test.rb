require File.dirname(__FILE__) + '/../test_helper'

class CacheTest < ZenaTestUnit
  
  def setup
    super
    @perform_caching_bak = ApplicationController.perform_caching
    Cache.perform_caching = true
  end
  
  def teardown
    Cache.perform_caching = @perform_caching_bak
  end
  
  def test_create_cache
    i = 1
    assert_equal "content 1", Cache.with(1,[2,3,4], 'NP', 'first', 'test')  { "content #{i}" }
    i = 2
    assert_equal "content 1", Cache.with(1,[2,3,4], 'NP', 'first', 'test')  { "content #{i}" }
    
    Cache.sweep(:visitor_id=>1)
    
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NP', 'first', 'test')  { "content #{i}" }
    i = 3
    assert_equal "content 3", Cache.with(1,[2,3,4], 'NP', 'second', 'test') { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NP', 'first' , 'test') { "content #{i}" }
    assert_equal "content 3", Cache.with(2,[3,8]  , 'NP', 'first' , 'test') { "content #{i}" }
    i = 4
    Cache.sweep(:visitor_groups=>[7,2])
    assert_equal "content 4", Cache.with(1,[2,3,4], 'NP', 'second', 'test') { "content #{i}" }
    assert_equal "content 4", Cache.with(1,[2,3,4], 'NP', 'first' , 'test') { "content #{i}" }
    assert_equal "content 3", Cache.with(2,[3,8]  , 'NP', 'first' , 'test') { "content #{i}" }
    i = 5
    Cache.sweep(:visitor_groups=>[8])
    assert_equal "content 4", Cache.with(1,[2,3,4], 'NP', 'second', 'test') { "content #{i}" }
    assert_equal "content 4", Cache.with(1,[2,3,4], 'NP', 'first' , 'test') { "content #{i}" }
    assert_equal "content 5", Cache.with(2,[3,8]  , 'NP', 'first' , 'test') { "content #{i}" }
    i = 6
    Cache.sweep(:context=>['first', 'test'])
    assert_equal "content 4", Cache.with(1,[2,3,4], 'NP', 'second', 'test') { "content #{i}" }
    assert_equal "content 6", Cache.with(1,[2,3,4], 'NP', 'first' , 'test') { "content #{i}" }
    assert_equal "content 6", Cache.with(2,[3,8]  , 'NP', 'first' , 'test') { "content #{i}" }
  end
  
  def test_kpath
    i = 1
    assert_equal "content 1", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    i = 2                                                        
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }
    
    # Sweep called on document (NPD) change, must remove 'NP' cache only
    Cache.sweep(:visitor_id=>1, :kpath=>'NPD')
    i = 3
    assert_equal "content 3", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }
    
    Cache.sweep(:visitor_id=>1, :kpath=>'I') # sweeps nothing
    i = 4
    assert_equal "content 3", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }
  end
end
