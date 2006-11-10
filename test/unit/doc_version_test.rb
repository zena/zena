require File.dirname(__FILE__) + '/../test_helper'

class DocVersionTest < UnitTestCase
  fixtures :versions, :items

  def test_cannot_set_file_ref
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(AccessViolation) { version.file_ref = items_id(:lake) }
  end
  
  def test_cannot_set_file_ref_by_attribute
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(AccessViolation) { version[:file_ref] = items_id(:lake) }
  end
end
