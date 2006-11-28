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
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_raise(Zena::AccessViolation) { item.v_item_id = items_id(:lake) }
  end
  
  def test_cannot_set_item_id_by_attribute
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_raise(Zena::AccessViolation) { item.update_attributes(:v_item_id=>items_id(:lake)) }
  end
  
  def test_cannot_set_item_id_on_create
    assert_raise(Zena::AccessViolation) { Item.create(:v_item_id=>items_id(:lake)) }
  end
  
  def test_cannot_set_content_id
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_raise(Zena::AccessViolation) { item.v_content_id = items_id(:lake) }
  end
  
  def test_cannot_set_content_id_by_attribute
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_raise(Zena::AccessViolation) { item.update_attributes(:v_content_id=>items_id(:lake)) }
  end
  
  def test_cannot_set_content_id_on_create
    assert_raise(Zena::AccessViolation) { Item.create(:v_content_id=>items_id(:lake)) }
  end
  
  def test_version_number_edit_by_attribute
    visitor(:ant)
    item = secure(Item) { items(:ant) }
    version = item.send(:version)
    assert_equal 1, version.number
    # edit
    item.v_title='new title'
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
    assert item.update_attributes(:v_title=>'new title')
    # saved
    # version number changed
    version = item.send(:version)
    assert_equal 2, version.number
  end
  
  def test_presence_of_item
    visitor(:tiger)
    item = secure(Item) { Item.new(:parent_id=>1, :name=>'bob') }
    assert item.save
    vers = Version.new
    assert !vers.save
    assert_equal "can't be blank", vers.errors[:item]
    assert_equal "can't be blank", vers.errors[:user]
  end
  
  def test_update_content_one_version
    preserving_files("/data/test/pdf/36") do
      visitor(:ant)
      set_lang('en')
      item = secure(Item) { items(:forest_pdf) }
      assert_equal Zena::Status[:red], item.v_status
      assert_equal versions_id(:forest_red_en), item.c_version_id
      assert_equal 63569, item.c_size
      # single redaction: ok
      assert item.update_attributes(:c_file=>uploaded_pdf('water.pdf')), 'Can edit item'
      # version and content did not change
      assert_equal versions_id(:forest_red_en), item.c_version_id
      assert_equal 29279, item.c_size
      assert_kind_of Tempfile, item.c_file
      assert_equal 29279, item.c_file.stat.size
    end
  end
  
  def test_cannot_change_content_if_many_uses
    preserving_files("/data/test/pdf") do
      visitor(:ant)
      set_lang('fr')
      item = secure(Item) { items(:forest_pdf) }
      old_vers_id = item.v_id
      # ant's english redaction
      assert_equal 'en', item.v_lang
      assert item.update_attributes(:v_title=>'les arbres')

      # new redaction for french
      assert_not_equal item.v_id, old_vers_id
      
      # new redaction points to old content
      assert_equal     item.v_content_id, old_vers_id
      
      visitor(:ant)
      set_lang('en')
      item = secure(Item) { items(:forest_pdf) }
      # get ant's english redaction
      assert_equal old_vers_id, item.v_id
      # try to edit content
      assert !item.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Cannot be changed"
      assert_match "cannot change content (used by other versions)", item.errors[:base]
    end
  end
end
