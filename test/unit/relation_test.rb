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
  
  def test_can_create
    login(:lion) # admin
    relation = Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>")
    assert !relation.new_record?
    assert_equal sites_id(:zena), relation[:site_id]
  end
  
  def test_cannot_set_site_id
    login(:lion) # admin
    relation = Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>", :site_id => sites_id(:ocean))
    assert !relation.new_record?
    assert_equal sites_id(:zena), relation[:site_id]
  end
  
  def test_set_site_id
    login(:lion) # admin
    relation = Relation.find(:first)
    assert_raise(Zena::AccessViolation) { relation.site_id = sites_id(:ocean) }
  end
  
  def test_can_update
    login(:lion) # admin
    relation = relations(:node_has_tags)
    assert relation.update_attributes(:target_kpath => 'NP')
    assert_equal 'NP', relation.target_kpath
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
  
  def test_ant_favorites
    login(:ant)
    ant = secure(User) { users(:ant) }
    assert_equal 1, ant.contact.relation('favorites').size
  end
  
  def test_set_relation_method_missing
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert node.update_attributes( 'tag_ids' => ['23'] )
    assert_equal [23], node.tag_ids
    node = secure(Node) { nodes(:status) } # reload
    assert_equal 23, node.relation('tags')[0][:id]
    assert_equal [23], node.tag_ids
    assert_equal [33], node.tag_zips
  end
  
  def test_relation_proxy
    node = secure(Node) { nodes(:status) }
    assert relation = node.relation_proxy('hot_for')
    assert relation = node.relation_proxy('tags')
    assert_kind_of Relation, relation
  end
  
  def test_has_relation
    assert Page.has_relation?('hot_for')
    assert Page.has_relation?('tags')
    assert ! Page.has_relation?('super')
    assert ! Page.has_relation?('nodes')
    assert ! Page.has_relation?('favorites')
    assert Contact.has_relation?('favorites')
  end
  
  def test_bad_attribute_raises
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise (NoMethodError) { node.update_attributes( 'tralala_ids' => ['33'])}
    assert_raise (NoMethodError) { node.some_bad_method_name }
  end
  
  def test_relations_for_form
    login(:tiger)
    {
      Note    => ["blog", "calendar", "favorite_for", "home_for", "hot_for", "icon", "reference", "tag"],
      Image   => ["favorite_for", "home_for", "hot_for", "icon", "icon_for", "reference", "tag"],
      Project => ["collaborator", "favorite_for", "home", "home_for", "hot", "hot_for", "icon", "news", "post", "reference", "tag"],
      Contact => ["collaborator_for", "favorite", "favorite_for", "home_for", "hot_for", "icon", "reference", "reference_for", "tag"],
    }.each do |klass, roles|
      node = secure(klass) { klass.find(:first) }
      assert_equal roles, node.relations_for_form.map{|a,b| a}
    end
  end
  
  def test_destroy_links
    assert false, "TODO"
  end
  
  def test_relation_new_record
    login(:tiger)
    node = secure(Node) { Node.new }
    assert_equal nil, node.relation('tags')
    node = secure(Node) { Node.get_class('Tag').new }
    assert_equal nil, node.relation('tag_for')
  end
end
