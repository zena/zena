require File.dirname(__FILE__) + '/../test_helper'

class RelationTest < ZenaTestUnit
  
  def test_cannot_create
    login(:ant) # not an admin
    relation = Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>")
    assert relation.new_record?
    assert_equal "you do not have the rights to do this", relation.errors[:base]
  end
  
  def test_cannot_update
    login(:ant) # not an admin
    relation = relations(:node_has_tags)
    assert !relation.update_attributes(:target_kpath => 'NP')
    assert_equal "you do not have the rights to do this", relation.errors[:base]
  end
  
  def test_get_relation
    node = secure(Node) { nodes(:opening) }
    assert calendars = node.relation('calendars')
    assert_equal 2, calendars.size
    calendars.each do |obj|
      assert_kind_of Project, obj
    end
  end
  
  def test_set_relation
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert node.set_relation('tag',['23'])
    assert node.save
    node = secure(Node) { nodes(:status) } # reload
    assert_equal 23, node.relation('tags')[0][:id]
  end

  def test_remove_link
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    assert calendars = node.relation('calendars')
    assert_equal 2, calendars.size
    node.remove_link(links_id(:opening_in_zena))
    assert node.save
    node = secure(Node) { nodes(:opening) } # reload
    assert calendars = node.relation('calendars')
    assert_equal 1, calendars.size
  end
  
  def test_add_link
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_nil node.relation('tags')
    node.add_link('tag', nodes_id(:art))
    assert node.save
    node = secure(Node) { nodes(:status) } # reload
    assert tags = node.relation('tags')
    assert_equal 1, tags.size
  end
  
  def test_set_relation_method_missing
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert node.update_attributes( 'tag_ids' => ['23'] )
    node = secure(Node) { nodes(:status) } # reload
    assert_equal 23, node.relation('tags')[0][:id]
  end
end
