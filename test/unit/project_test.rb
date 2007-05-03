require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < ZenaTestUnit

  
  def test_project_id_on_create
    login(:tiger)
    node = secure(Project) { Project.create(:parent_id=>nodes_id(:status), :name=>'SuperProject') }
    assert ! node.new_record?, 'Not a new record'
    assert_equal node[:id], node.get_project_id
    assert_equal nodes_id(:cleanWater), node[:project_id]
    child = secure(Page) { Page.create(:parent_id=>node[:id], :name=>'child')}
    assert ! node.new_record?, "Not a new record"
    assert_equal node[:id], child[:project_id]
  end
  
  def test_update_set_project_id_on_update
    login(:tiger)
    node = secure(Project) { Project.find(nodes_id(:cleanWater))}
    assert_equal nodes_id(:cleanWater), node.get_project_id
    node[:parent_id] = nodes_id(:zena)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:cleanWater), node.get_project_id
    assert_equal nodes_id(:zena), node[:project_id]
    node[:project_id] = nodes_id(:zena)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:cleanWater), node.get_project_id
    assert_equal nodes_id(:zena), node[:project_id]
  end
  
  def test_notes
    login(:tiger)
    project = secure(Project) { Project.find(nodes_id(:cleanWater)) }
    notes = nil
    assert_nothing_raised { notes = project.notes }
    assert_equal 1, notes.size
    assert_equal 'opening', notes[0].name
    note = secure(Note) { Note.create(:parent_id=>nodes_id(:cleanWater), :v_title=>'hello')}
    assert !note.new_record?, "Not a new record"
    notes = project.notes
    assert_equal 2, notes.size
  end
  
  def test_notes_with_find
    login(:tiger)
    project = secure(Project) { Project.find(nodes_id(:cleanWater)) }
    note = secure(Note) { Note.create(:parent_id=>nodes_id(:cleanWater), :v_title=>'hello')}
    assert !note.new_record?, "Not a new record"
    notes = project.notes
    assert_equal 2, notes.size
    notes = project.notes(:conditions=>"name LIKE 'hell%'")
    assert_equal 1, notes.size
    assert_equal 'hello', notes[0].name
  end
    
end
