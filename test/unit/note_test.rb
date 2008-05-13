require File.dirname(__FILE__) + '/../test_helper'

class NoteTest < ZenaTestUnit
  
  def test_create_with_name
    login(:tiger)
    note = nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:name=>"asdf", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
  end
  
  def test_create_with_title
    login(:tiger)
    note = nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:v_title=>"Monday is nice", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "MondayIsNice", note[:name]
  end
  
  def test_create_same_name
    login(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:name=>"test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure!(Note) { Note.create(:name=>"test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert ! note2.new_record? , "Not a new record" # same name allowed for notes
  end
  
  def test_create_same_name_other_day
    login(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:name=>"test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]

    assert_nothing_raised { note2 = secure!(Note) { Note.create(:name=>"test", :parent_id=>nodes_id(:zena), :log_at=>"2006-07-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert !note2.new_record? , "Not a new record"
    assert_equal "test", note2[:name]
  end

  
  def test_update_same_name
    login(:tiger)
    note, note2 = nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:name=>"test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure!(Note) { Note.create(:name=>"asdf", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note2.new_record? , "Not a new record"
    
    note2.name = "test"
    assert note2.save
  end
  
  # test fullpath
end