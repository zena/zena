require File.dirname(__FILE__) + '/../test_helper'

class DataEntryTest < ZenaTestUnit
  
  def test_site_id
    login(:tiger)
    ent = DataEntry.create(:node_a_id => nodes_id(:status), :text => "simple test")
    assert !ent.new_record?, "Not a new record"
    assert_equal sites_id(:zena), ent[:site_id]
  end
  
  def test_other_site_id_fool_id
    login(:whale)
    assert_raise(Zena::AccessViolation) { ent = DataEntry.create(:node_a_id => nodes_id(:ocean), :site_id=>sites_id(:zena)) }
  end
  
  def test_no_nodes
    login(:tiger)
    ent = DataEntry.create(:text => "simple test")
    assert ent.new_record?, "New record"
    assert_equal "a data entry must link to at least one node", ent.errors[:base]
  end
  
  def test_nodes
    login(:tiger)
    ent = data_entries(:comment)
    assert_equal [nodes_id(:secret),nodes_id(:status)], ent.nodes.map {|n| n.id}.sort
    login(:ant)
    assert_equal [nodes_id(:status)], ent.nodes.map {|n| n.id}.sort
  end
  
  def test_node_a
    login(:tiger)
    ent = data_entries(:comment)
    assert_equal nodes_id(:status), ent.node_a[:id]
  end
  
  def test_cannot_change_old_link
    login(:ant)
    ent = data_entries(:comment)
    assert !ent.update_attributes(:node_a_id => nodes_id(:ant), :node_b_id => nodes_id(:zena))
    assert ent.errors[:node_b_id]
    assert_equal "cannot remove old relation", ent.errors[:node_b_id]
  end
  
  def test_cannot_set_bad_link
    login(:ant)
    ent = data_entries(:comment)
    assert !ent.update_attributes(:node_c_id => nodes_id(:secret))
    assert ent.errors[:node_c_id]
    assert_equal "invalid node", ent.errors[:node_c_id]
  end
  
  def test_data_precision
    login(:ant)
    ent = DataEntry.create(:node_a_id => nodes_id(:status), :value => 3.1415926535897932384)
    ent = DataEntry.find(ent[:id])
    assert_equal 3.14159265, ent.value.to_f  # crop to 8 digit precision
  end
end
