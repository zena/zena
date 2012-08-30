require 'test_helper'

class ProjectTest < Zena::Unit::TestCase


  def test_project_id_on_create
    login(:tiger)
    node = secure!(Project) { Project.create(:parent_id=>nodes_id(:status), :title =>'SuperProject') }
    assert ! node.new_record?, 'Not a new record'
    assert_equal node[:id], node.get_project_id
    assert_equal nodes_id(:cleanWater), node[:project_id]
    child = secure!(Page) { Page.create(:parent_id=>node[:id], :title =>'child')}
    assert ! node.new_record?, "Not a new record"
    assert_equal node[:id], child[:project_id]
  end

  def test_update_set_project_id_on_update
    login(:tiger)
    node = secure!(Project) { Project.find(nodes_id(:cleanWater))}
    assert_equal nodes_id(:cleanWater), node.get_project_id
    node[:parent_id] = nodes_id(:zena)
    if !node.save
      assert false, "Can save node (#{err(node)})"
    else
      assert true
    end
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
