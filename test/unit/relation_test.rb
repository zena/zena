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
  
  def test_find_relation
    node = secure(Node) { nodes(:opening) }
    assert calendars = node.find(:all, 'calendars')
    assert_equal 2, calendars.size
    calendars.each do |obj|
      assert_kind_of Project, obj
    end
    assert calendars = node.find(:all, :relations=>['calendars'])
    assert_equal 2, calendars.size
    calendars.each do |obj|
      assert_kind_of Project, obj
    end
  end
  
  def test_find_relation_with_alternative
    node = secure(Node) { nodes(:wiki) }
    assert projects_and_images = node.find(:all, :relations=>['projects from site', 'images'])
    assert_equal [20, 11, 21, 19, 1], projects_and_images.map{|r| r[:id]}
    projects_and_images.each do |r|
      assert((r.kind_of?(Image) && r.parent_id == node[:id]) || r.kind_of?(Project))
    end
  end
  
  # TEST TO HERE
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

  def test_build_find_class
    assert_equal "SELECT nodes.* FROM nodes WHERE (nodes.kpath LIKE 'NN%' AND nodes.parent_id = \#{var8[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['notes'], :node=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:opening)], res.map{|r| r[:id]}
  end
  
  def test_build_find_class_from_site
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes WHERE (nodes.kpath LIKE 'NN%' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['notes from site'], :node=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:letter), nodes_id(:opening), nodes_id(:proposition)], res.map{|r| r[:id]}
  end
  
  def test_build_find_vclass_from_project
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes WHERE (nodes.kpath LIKE 'NNP%' AND nodes.project_id = \#{var8.get_project_id} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['posts from project'], :node=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:opening)], res.map{|r| r[:id]}
  end
  
  def test_build_find_vclass_from_project_or_class
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes WHERE (((nodes.kpath LIKE 'NNP%' AND nodes.project_id = \#{var8.get_project_id}) OR (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.parent_id = \#{var8[:id]})) AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['posts from project','pages'], :node=>'var8')

    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas, :opening, :status, :tracker].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_bad_vclass_from_project
    assert_equal "SELECT nodes.* FROM nodes WHERE (nodes.id IS NULL AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['badclass from project'], :node=>'var8')

    var8 = secure(Node) { nodes(:cleanWater) }
    assert_nil var8.do_find(:all, eval("\"#{str}\""))
  end
  
  def test_build_find_relation
    assert_equal "SELECT nodes.* FROM nodes  LEFT JOIN links AS lk1 ON lk1.target_id = nodes.id WHERE (lk1.relation_id = 9 AND lk1.source_id = \#{var8[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['favorites'], :node=>'var8')
    
    login(:ant)
    var8 = secure(Node) { nodes(:ant) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:nature].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end

  def test_build_find_relation_with_class
    assert_equal "SELECT nodes.* FROM nodes  LEFT JOIN links AS lk1 ON lk1.source_id = nodes.id WHERE (((nodes.kpath LIKE 'NPDI%' AND nodes.parent_id = \#{var8[:id]}) OR (lk1.relation_id = 1 AND lk1.target_id = \#{var8[:id]})) AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['images','news'], :node=>'var8')
    login(:ant)
    var8 = secure(Node) { nodes(:wiki) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bird_jpg, :flower_jpg, :opening].map{|s| nodes_id(s)}, res.map{|r| r[:id]}    
  end

  def test_build_find_with_dyn_attribute_clause
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) INNER JOIN dyn_attributes AS da1 ON da1.owner_id = vs.id AND da1.owner_table = 'versions' WHERE (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.section_id = \#{var8.get_section_id} AND da1.key = 'assigned' AND da1.value = 'gaspard' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['pages from section where d_assigned = "gaspard"'], :node=>'var8')
    login(:ant)
    var8 = secure(Node) { nodes(:zena) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:cleanWater, :people].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_with_version_clause
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) WHERE (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.project_id = \#{var8.get_project_id} AND vs.comment = 'no comment yet' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['pages from project where v_comment = "no comment yet"'], :node=>'var8')
    login(:lion)
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas, :strange].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  
  def test_build_find_with_version_clause_year
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) WHERE (1 AND nodes.project_id = \#{var8.get_project_id} AND year(vs.updated_at) = '2007' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['nodes from project where v_updated_at:year = 2007'], :node=>'var8')
    login(:lion)
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
end
