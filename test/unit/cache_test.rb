require 'test_helper'

# Cache has been thrown to hell.

=begin
class CacheTest < Zena::Unit::TestCase

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

  def test_after_all_cache_sweep
    login(:lion)
    i = 1
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    i = 2
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }

    # do something on a project
    node = secure!(Node) { nodes(:wiki) }
    assert_equal 'NPP', node.class.kpath
    assert node.update_attributes(:title=>'new title'), "Can change attributes"
    # sweep only kpath NPP
    i = 3
    assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }

    # do something on a note
    node = secure!(Node) { nodes(:proposition) }
    assert_equal 'NNP', node.vclass.kpath
    assert node.update_attributes(:log_at => Time.now), "Can change attributes"
    # sweep only kpath NN
    i = 4
    assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 4", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
  end

  def test_kpath
    i = 1
    assert_equal "content 1", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    i = 2
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }

    # Sweep called on project (NPP) change, must remove 'NP' cache only
    Cache.sweep(:visitor_id=>1, :kpath=>'NPP')
    i = 3
    assert_equal "content 3", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }

    Cache.sweep(:visitor_id=>1, :kpath=>'I') # sweeps nothing
    i = 4
    assert_equal "content 3", Cache.with(1,[2,3,4], 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 2", Cache.with(1,[2,3,4], 'NN', 'notes')  { "content #{i}" }
  end
end
=end