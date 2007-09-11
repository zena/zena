require File.dirname(__FILE__) + '/../test_helper'

class PageTest < ZenaTestUnit
  
  def test_create_just_v_title
    login(:tiger)
    node = secure(Page) { Page.create(:parent_id=>nodes_id(:projects), :v_title=>'lazy node')}
    assert !node.new_record?
    assert_equal 'lazyNode', node.name
    assert_equal 'lazy node', node.v_title
  end
  
  def test_create_same_name
    login(:tiger)
    node = secure(Page) { Page.create(:parent_id=>nodes_id(:projects), :name=>'wiki')}
    assert node.new_record?
    assert_equal 'has already been taken', node.errors[:name]
  end
  
  def test_create_same_name_other_parent
    login(:tiger)
    node = secure(Page) { Page.create(:parent_id=>21, :name=>'wiki')}
    assert ! node.new_record?, 'Not a new record'
    assert_nil node.errors[:name]
  end
  
  def test_create_same_name_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure(Page) { Page.create(:parent_id=>21, :name=>'wiki')}
      assert ! node.new_record?, 'Not a new record'
      assert_nil node.errors[:name]
    end
  end

  def test_update_same_name
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    node.name = 'wiki'
    assert ! node.save, 'Cannot save'
    assert_equal node.errors[:name], 'has already been taken'
  end

  def test_update_same_name_other_parent
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    node.name = 'wiki'
    node[:parent_id] = 1
    assert node.save
    assert_nil node.errors[:name]
  end
  
  def test_update_same_name_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure(Node) { nodes(:cleanWater) }
      node.name = 'wiki'
      node[:parent_id] = 1
      assert node.save
      assert_nil node.errors[:name]
    end
  end
  
  def test_custom_base_path
    login(:tiger)
    node = secure(Node) { nodes(:wiki) }
    bird = secure(Node) { nodes(:bird_jpg)}
    assert_equal '', node.basepath
    assert_equal '', bird.basepath
    assert_equal node[:id], bird[:parent_id]
    
    assert node.update_attributes(:custom_base => true)
    assert_equal 'projects/wiki', node.basepath
    assert_equal 'projects/wiki', bird.basepath
  end
end
