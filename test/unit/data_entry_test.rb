require 'test_helper'

class DataEntryTest < Zena::Unit::TestCase
  
  def test_site_id
    login(:tiger)
    ent = DataEntry.create(:node_a_id => nodes_id(:wiki), :text => "simple test")
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
    assert_equal [nodes_id(:secret),nodes_id(:wiki)].sort, ent.nodes.map {|n| n.id}.sort
    login(:ant)
    assert_equal [nodes_id(:wiki)], ent.nodes.map {|n| n.id}.sort
  end
  
  def test_node_a
    login(:tiger)
    ent = data_entries(:comment)
    assert_equal nodes_id(:secret), ent.node_a[:id]
  end
  
  def test_cannot_change_old_link
    login(:ant)
    ent = data_entries(:comment)
    assert !ent.update_attributes(:node_a_id => nodes_id(:ant), :node_a_id => nodes_id(:zena))
    assert ent.errors[:node_a_id].any?
    assert_equal "cannot remove old relation", ent.errors[:node_a_id]
  end
  
  def test_cannot_set_bad_link
    login(:ant)
    ent = data_entries(:comment)
    assert !ent.update_attributes(:node_c_id => nodes_id(:secret))
    assert ent.errors[:node_c_id].any?
    assert_equal "invalid node", ent.errors[:node_c_id]
  end
  
  def test_data_precision
    login(:ant)
    ent = DataEntry.create(:node_a_id => nodes_id(:wiki), :value_a => 3.1415926535897932384, :value_b => 0.1234567890)
    ent = DataEntry.find(ent[:id])
    assert_equal BigDecimal("3.14159265"), ent.value    # round to 8 digit precision
    assert_equal BigDecimal("0.12345679"), ent.value_b  # round to 8 digit precision
  end
  
  def test_clone
    login(:ant)
    ent = data_entries(:comment)
    clone = ent.clone
    assert_equal nodes_id(:secret), clone[:node_a_id]
    assert_equal nodes_id(:wiki), clone[:node_b_id]
    assert_nil clone[:node_c_id]
    assert_nil clone[:node_d_id]
    assert_nil clone[:text]
    assert_nil clone[:date]
    assert_nil clone[:value_a]
  end
  
  def test_can_write
    login(:anon)
    ent = data_entries(:comment)
    assert !ent.can_write?
    login(:tiger)
    ent = data_entries(:comment)
    assert ent.can_write?
  end
end
