require 'test_helper'

class PageTest < Zena::Unit::TestCase

  def test_create_just_title
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:projects), :title=>'lazy node')}
    err node
    assert !node.new_record?
    assert_equal 'lazy node', node.title
  end

  def test_create_same_title
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:projects), :title =>'a wiki with Zena')}
    assert node.new_record?
    assert_equal 'has already been taken', node.errors[:title]
  end

  def test_create_same_title_other_parent
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:cleanWater), :title =>'a wiki with Zena')}
    err node
    assert ! node.new_record?, 'Not a new record'
    assert_nil node.errors[:title] #.empty?
  end

  def test_create_same_title_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure!(Page) { Page.create(:parent_id=>nodes_id(:cleanWater), :title =>'a wiki with Zena')}
      err node
      assert ! node.new_record?, 'Not a new record'
      assert_nil node.errors[:title] #.empty?
    end
  end

  def test_update_same_title
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    # publish so that we change title and check uniqueness
    assert !node.update_attributes('title' => 'a wiki with Zena', :v_status => Zena::Status[:pub])
    assert_equal 'has already been taken', node.errors[:title]
  end

  def test_update_same_title_other_parent
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    node.title = 'a wiki with Zena'
    node[:parent_id] = nodes_id(:zena)
    assert node.save
    assert_nil node.errors[:title] #.empty?
  end

  def test_update_same_title_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure!(Node) { nodes(:cleanWater) }
      node.title = 'a wiki with Zena'
      node[:parent_id] = nodes_id(:zena)
      assert node.save
      assert_nil node.errors[:title] #.empty?
    end
  end

  def test_custom_base_path
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal '', node.basepath
    assert_equal '', bird.basepath
    assert_equal node[:id], bird[:parent_id]
    assert node.update_attributes(:custom_base => true)
    assert_equal '18/29', node.basepath
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal '18/29', bird.basepath
  end
end
