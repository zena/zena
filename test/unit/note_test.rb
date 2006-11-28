require File.dirname(__FILE__) + '/../test_helper'

class NoteTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_create_with_name
    visitor(:tiger)
    note = nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"asdf", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
  end
  
  def test_create_with_title
    visitor(:tiger)
    note = nil
    assert_nothing_raised { note = secure(Note) { Note.create(:v_title=>"Monday is nice", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "MondayIsNice", note[:name]
  end
  
  def test_create_same_name
    visitor(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"test", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure(Note) { Note.create(:name=>"test", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note2.new_record? , "Is not saved (new_record)"
    assert note2.errors[:name]
    
    assert_nothing_raised { note3 = secure(Note) { Note.create(:v_title=>"test", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note3.new_record? , "Not saved"
    assert note3.errors[:name]
  end
  
  def test_update_same_name
    visitor(:tiger)
    note, note2 = nil, nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"test", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure(Note) { Note.create(:name=>"asdf", :parent_id=>items_id(:zena), :log_at=>"20.06.2006", :tag_ids=>[items_id(:news)])} }
    assert note , "Note created"
    assert ! note2.new_record? , "Not a new record"
    
    note2.name = "test"
    assert ! note2.save
    assert note2.errors[:name]
  end
  
  # test parent is project
  # test a page cannot use a note as parent
  # test a document can use a note as parent
  # test fullpath
end