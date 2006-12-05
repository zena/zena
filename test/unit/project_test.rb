require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def test_check_project_id_on_create
    visitor(:tiger)
    item = secure(Project) { Project.create(:parent_id=>items_id(:status), :name=>'SuperProject') }
    assert ! item.new_record?, 'Not a new record'
    assert_equal item[:id], item[:project_id]
  end
  
  def test_update_set_project_id_on_update
    visitor(:tiger)
    item = secure(Project) { Project.find(items_id(:cleanWater))}
    assert_equal items_id(:cleanWater), item[:project_id]
    item[:parent_id] = items_id(:zena)
    assert item.save, 'Can save item'
    item.reload
    assert_equal items_id(:cleanWater), item[:project_id]
    item[:project_id] = items_id(:zena)
    assert item.save, 'Can save item'
    item.reload
    assert_equal items_id(:cleanWater), item[:project_id]
  end
  
  def test_notes
    visitor(:tiger)
    project = secure(Project) { Project.find(items_id(:cleanWater)) }
    notes = nil
    assert_nothing_raised { notes = project.notes }
    assert_equal 1, notes.size
    assert_equal 'opening', notes[0].name
    note = secure(Note) { Note.create(:parent_id=>items_id(:cleanWater), :v_title=>'hello')}
    assert !note.new_record?, "Not a new record"
    notes = project.notes
    assert_equal 2, notes.size
  end
  
  def test_notes_with_find
    visitor(:tiger)
    project = secure(Project) { Project.find(items_id(:cleanWater)) }
    note = secure(Note) { Note.create(:parent_id=>items_id(:cleanWater), :v_title=>'hello')}
    assert !note.new_record?, "Not a new record"
    notes = project.notes
    assert_equal 2, notes.size
    notes = project.notes(:conditions=>"name LIKE 'hell%'")
    assert_equal 1, notes.size
    assert_equal 'hello', notes[0].name
  end
    
end
