require File.dirname(__FILE__) + '/../test_helper'

class VersionTest < UnitTestCase
  fixtures :versions, :comments, :items
  
  def test_cannot_set_item_id
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(AccessViolation) { version.item_id = items_id(:lake) }
  end
  
  def test_cannot_set_item_id_by_attribute
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(AccessViolation) { version[:item_id] = items_id(:lake) }
  end
  
  def test_version_number_edit_by_attribute
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_equal 1, version.number
    # edit
    item.title='new title'
    version = item.send(:version)
    assert_nil version.number
    # save
    assert item.save, "Item can be saved"
    # version number changed
    version = item.send(:version)
    assert_equal 2, version.number
  end
    
  def test_version_number_edit
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_equal 1, version.number
    # can edit
    assert item.edit(:title=>'new title')
    # saved
    # version number changed
    version = item.send(:version)
    assert_equal 2, version.number
  end
end
