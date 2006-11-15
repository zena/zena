require File.dirname(__FILE__) + '/../test_helper'

class NoteTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def test_create_with_name
    visitor(:tiger)
    note = nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"asdf", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
  end
  
  def test_create_with_title
    visitor(:tiger)
    note = nil
    assert_nothing_raised { note = secure(Note) { Note.create(:title=>"Monday is nice", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "MondayIsNice", note[:name]
  end
  
  def test_create_same_name
    visitor(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"test", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure(Note) { Note.create(:name=>"test", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note2.new_record? , "Is not saved (new_record)"
    assert note2.errors[:name]
    
    assert_nothing_raised { note3 = secure(Note) { Note.create(:title=>"test", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note3.new_record? , "Not saved"
    assert note3.errors[:name]
  end
  
  def test_update_same_name
    visitor(:tiger)
    note, note2 = nil, nil
    assert_nothing_raised { note = secure(Note) { Note.create(:name=>"test", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note[:name]
    
    assert_nothing_raised { note2 = secure(Note) { Note.create(:name=>"asdf", :text=>"asdf", :parent_id=>items_id(:zena), :blog_at=>"20.06.2006", :collected=>items_id(:news))} }
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
=begin
  def test_parent_for_Note 
    # parent for Note
    item = Note.new(
      :rgroup_id => 1,
      :wgroup_id => 2,
      :pgroup_id => 3,
      :parent_id => items(:sport).id
    )
    assert ! item.save
    assert item.errors[:parent_id]
  end
end
=end