require File.dirname(__FILE__) + '/../test_helper'
class VersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def version(sym)
    secure(Item) { items(sym) }.send(:version)
  end
  
  def test_author
    visitor(:tiger)
    v = version(:status)
    assert_equal v[:user_id], v.author[:id]
  end
  
  def test_cannot_set_item_id
    visitor(:ant)
    version = version(:ant)
    assert_raise(Zena::AccessViolation) { version.item_id = items_id(:lake) }
  end
  
  def test_cannot_set_item_id_by_attribute
    visitor(:ant)
    version = version(:ant)
    assert_raise(Zena::AccessViolation) { version.update_attributes(:item_id=>items_id(:lake)) }
  end
  
  def test_cannot_set_item_id_on_create
    visitor(:ant)
    assert_raise(Zena::AccessViolation) { Version.create(:item_id=>items_id(:lake)) }
  end
  
  def test_version_number_edit_by_attribute
    visitor(:ant)
    item = secure(Item) { items(:ant) }
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
    item = secure(Item) { items(:ant) }
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
