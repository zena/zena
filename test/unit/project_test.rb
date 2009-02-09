require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end

  
  def test_project_id_on_create
    login(:tiger)
    node = secure!(Project) { Project.create(:parent_id=>nodes_id(:status), :name=>'SuperProject') }
    assert ! node.new_record?, 'Not a new record'
    assert_equal node[:id], node.get_project_id
    assert_equal nodes_id(:cleanWater), node[:project_id]
    child = secure!(Page) { Page.create(:parent_id=>node[:id], :name=>'child')}
    assert ! node.new_record?, "Not a new record"
    assert_equal node[:id], child[:project_id]
  end
  
  def test_update_set_project_id_on_update
    login(:tiger)
    node = secure!(Project) { Project.find(nodes_id(:cleanWater))}
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
end
