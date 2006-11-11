require File.dirname(__FILE__) + '/../test_helper'

class Item < ActiveRecord::Base
  link :icon, :class=>Image, :unique=>true
  link :tags, :class=>Collector
  link :tagged, :class=>Item, :as=>'tag'
end

class LinkTest < UnitTestCase
  fixtures :items, :versions, :addresses, :groups, :groups_users
  
  def test_link_icon
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    assert_nil @item.icon
    @item.icon=(20)
    assert_kind_of Image, icon = @item.icon
    assert_equal 20, icon[:id]
    assert_equal "bird.jpg", icon.name
  end
  
  def test_bad_icon
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    assert_nil @item.icon
    @item.icon=('hello')
    assert_nil @item.icon
    @item.icon=(4) # bad class
    assert_equal 0, Link.find_all_by_source_id_and_role(1, 'icon').size
    @item.icon=(13645)
    assert_equal 0, Link.find_all_by_source_id_and_role(1, 'icon').size
  end
  
  def test_cannot_publish_link_icon
    visitor(:ant)
    @item = secure(Item) { Item.find(1) }
    assert !@item.can_drive?
    assert_nil @item.icon
    @item.icon=(20)
    assert @item.errors[:icon], "Cannot set icon"
  end
  
  def test_unique_icon
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    assert_nil @item.icon
    @item.icon=(20)
    assert_equal 20, @item.icon[:id]
    @item.icon=(21)
    assert_equal 21, @item.icon[:id]
    assert_equal 1, Link.find_all_by_source_id_and_role(1, 'icon').size
  end
  
  def test_remove_icon
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    assert_nothing_raised { @item.icon=(nil) }
    @item.icon=(20)
    assert_equal 20, @item.icon[:id]
    @item.icon=(nil)
    assert_nil @item.icon
    @item.icon=('20')
    assert_equal 20, @item.icon[:id]
    @item.icon=('')
    assert_nil @item.icon
  end
  
  def test_many_tags
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    assert_nothing_raised { @item.tags }
    assert_equal [], @item.tags
    @item.tags=([23,24])
    assert_nil @item.errors[:tag]
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
  end
  
  def test_cannot_publish_tags
    visitor(:ant)
    @item = secure(Item) { Item.find(1) }
    @item.tags=([23,24])
    assert @item.errors[:tag]
  end
  
  def test_can_remove_tag
    visitor(:lion)
    @item = secure(Item) { Item.find(1) }
    @item.tags=([23,24])
    assert_equal 2, @item.tags.size
    @item.remove_tag(23)
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'news', tags[0].name
  end
  
  def test_tagged
    assert false, 'test todo'
  end
end
