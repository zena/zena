require File.dirname(__FILE__) + '/../test_helper'

class SectionTest < ZenaTestUnit
  
  
  def test_section_id_on_create
    login(:tiger)
    node = secure(Section) { Section.create(:parent_id=>nodes_zip(:status), :name=>'SuperSection') }
    assert ! node.new_record?, 'Not a new record'
    assert_equal node[:id], node.get_section_id
    assert_equal nodes_id(:zena), node[:section_id]
    child = secure(Page) { Page.create(:parent_id=>node[:id], :name=>'child')}
    assert ! node.new_record?, "Not a new record"
    assert_equal node[:id], child[:section_id]
  end
  
  def test_update_set_section_id_on_update
    login(:tiger)
    node = secure(Section) { Section.find(nodes_id(:people))}
    assert_equal nodes_id(:people), node.get_section_id
    node[:parent_id] = nodes_id(:zena)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:zena), node[:section_id]
    node[:section_id] = nodes_id(:zena)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:zena), node[:section_id]
  end
end
