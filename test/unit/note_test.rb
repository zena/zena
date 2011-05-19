require 'test_helper'

class NoteTest < Zena::Unit::TestCase

  def test_create_simplest
    login(:ant)
    test_page = secure!(Note) { Note.create(:title => "yoba", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert ! test_page.new_record? , "Not a new record"
    assert_equal nodes_id(:cleanWater), test_page.parent[:id]
    assert_equal "18/21/#{test_page.zip}", test_page.fullpath
    assert_equal '18/21', test_page.basepath
  end

  def test_create_with_title
    login(:tiger)
    note = nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:title=>"Monday is nice", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "Monday is nice", note.title
  end

  def test_create_same_title
    login(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:title => "test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note.title

    assert_nothing_raised { note2 = secure!(Note) { Note.create(:title => "test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert ! note2.new_record? , "Not a new record" # same title allowed for notes
  end

  def test_create_same_title_other_day
    login(:tiger)
    note, note2, note3 = nil, nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:title => "test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note.title

    assert_nothing_raised { note2 = secure!(Note) { Note.create(:title => "test", :parent_id=>nodes_id(:zena), :log_at=>"2006-07-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert !note2.new_record? , "Not a new record"
    assert_equal "test", note2.title
  end


  def test_update_same_title
    login(:tiger)
    note, note2 = nil, nil
    assert_nothing_raised { note = secure!(Note) { Note.create(:title => "test", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note.new_record? , "Not a new record"
    assert_equal "test", note.title

    assert_nothing_raised { note2 = secure!(Note) { Note.create(:title => "asdf", :parent_id=>nodes_id(:zena), :log_at=>"2006-06-20", :set_tag_ids=>[nodes_id(:news)])} }
    assert note , "Note created"
    assert ! note2.new_record? , "Not a new record"

    note2.title = "test"
    assert note2.save
  end

  def test_default_set_event_at
    login(:tiger)
    note = secure!(Note) { Note.create(:title => 'test', :parent_id => nodes_id(:zena), :event_at => '2009-06-15')}
    assert_equal '2009-06-15', note.event_at.strftime('%Y-%m-%d')
    assert_equal '2009-06-15', note.log_at.strftime('%Y-%m-%d')
  end

  def test_default_set_log_at
    login(:tiger)
    note = secure!(Note) { Note.create(:title => 'test', :parent_id => nodes_id(:zena), :log_at => '2009-06-15')}
    assert_equal '2009-06-15', note.event_at.strftime('%Y-%m-%d')
    assert_equal '2009-06-15', note.log_at.strftime('%Y-%m-%d')
  end

  def test_default_set_log_at_and_event_at
    login(:tiger)
    note = secure!(Note) { Note.create(:title => 'test', :parent_id => nodes_id(:zena), :event_at => '2009-06-15', :log_at => '2009-06-16')}
    assert_equal '2009-06-15', note.event_at.strftime('%Y-%m-%d')
    assert_equal '2009-06-16', note.log_at.strftime('%Y-%m-%d')
  end
  # test fullpath
end