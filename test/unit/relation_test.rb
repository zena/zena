require File.dirname(__FILE__) + '/../test_helper'

class RelationTest < ZenaTestUnit

  def test_find_by_role
    assert_equal relations_id(:note_has_calendars), Relation.find_by_role('news')[:id]
    assert_equal relations_id(:note_has_calendars), Relation.find_by_role('calendar')[:id]
    assert_nil Relation.find_by_role('badrole')
  end
  
  def test_find_by_role_and_kpath
    assert_equal relations_id(:note_has_calendars), Relation.find_by_role_and_kpath('news', 'NPP')[:id]
    assert_equal relations_id(:note_has_calendars), Relation.find_by_role_and_kpath('calendar', 'NN')[:id]
    assert_nil Relation.find_by_role_and_kpath('badrole', 'N')
    assert_nil Relation.find_by_role_and_kpath('news', 'NNP')
    assert_nil Relation.find_by_role_and_kpath('calendar', 'NP')
  end
  
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
  
  def test_find
    login(:ant)
    node = secure(Node) { nodes(:status) }
    assert_equal 'cleanWater', node.find(:first,'parent')[:name]
    assert_equal 'projects', node.find(:first,'parent').find(:first,'parent')[:name]
    assert_equal 'zena', node.find(:first,'root')[:name]
    assert_equal 'art', node.find(:first,'parent').find(:all,'tags')[0][:name]
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
    assert_equal 23, node.find(:all,'tags')[0][:id]
  end

  def test_remove_link
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    assert calendars = node.find(:all,'calendars')
    assert_equal 2, calendars.size
    node.remove_link(links_id(:opening_in_zena))
    assert node.save
    node = secure(Node) { nodes(:opening) } # reload
    assert calendars = node.find(:all,'calendars')
    assert_equal 1, calendars.size
  end
  
  def test_add_link
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_nil node.find(:all,'tags')
    node.add_link('tag', nodes_id(:art))
    assert node.save
    node = secure(Node) { nodes(:status) } # reload
    assert tags = node.find(:all,'tags')
    assert_equal 1, tags.size
    assert_equal nodes_id(:art), tags[0][:id]
  end
  
  def test_add_link_virtual_class
    login(:tiger)
    node = secure(Node) { nodes(:proposition) } # Post virtual class
    assert_kind_of Relation, node.relation_proxy('blog')
    assert_nil node.find(:all,'blogs')
    node.add_link('blog', nodes_id(:cleanWater))
    assert node.save
    node = secure(Node) { nodes(:proposition) } # reload
    assert blogs = node.find(:all,'blogs')
    assert_equal 1, blogs.size
    assert_equal nodes_id(:cleanWater), blogs[0][:id]
  end
  
  def test_add_link_virtual_class_bad_target
    login(:tiger)
    node = secure(Node) { nodes(:proposition) } # Post virtual class
    assert_kind_of Relation, node.relation_proxy('blog')
    assert_nil node.find(:all,'blogs')
    node.add_link('blog', nodes_id(:art))
    assert !node.save
    assert_equal 'invalid target', node.errors[:blog]
  end
  
  def test_relation_links
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    assert_equal [[relations_id(:post_has_blogs),     [nodes_id(:zena)]], 
                  [relations_id(:note_has_calendars), [nodes_id(:wiki), nodes_id(:zena)]], 
                  [relations_id(:node_has_tags),      [nodes_id(:art),  nodes_id(:news)]]], 
                  
                  node.relation_links.map{|r,l| [r.id, l.map{|r| r.id}]}
  end
  
  def test_ant_favorites
    login(:ant)
    ant = secure(User) { users(:ant) }
    assert_equal 1, ant.contact.find(:all,'favorites').size
  end
  
  def test_other_links
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    rel  = node.relation_proxy('tag')
    assert_equal [:opening_in_news,:opening_in_art].map{|s| links_id(s)}, rel.other_links.map{|r| r[:id]}
  end
  
  def test_other_ids
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    rel  = node.relation_proxy('tag')
    assert_equal [:news,:art].map{|s| nodes_id(s)}, rel.other_ids
  end
  
  def test_records
    login(:tiger)
    node = secure(Node) { nodes(:opening) }
    rel  = node.relation_proxy('tag')
    assert_equal [:art,:news].map{|s| nodes_id(s)}, rel.records.map{|r| r[:id]}
  end
  
  def test_set_relation_method_missing
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert node.update_attributes( 'tag_ids' => ['23'] )
    assert_equal [23], node.tag_ids
    node = secure(Node) { nodes(:status) } # reload
    assert_equal 23, node.find(:all,'tags')[0][:id]
    assert_equal [23], node.tag_ids
    assert_equal [33], node.tag_zips
  end
  
  def test_relation_proxy
    node = secure(Node) { nodes(:status) }
    assert relation = node.relation_proxy('hot_for')
    assert relation = node.relation_proxy('tags')
    assert_nil node.relation_proxy('hot')
    node = secure(Node) { nodes(:cleanWater) }
    assert relation = node.relation_proxy('hot_for')
    assert relation = node.relation_proxy('hot')
    assert relation = node.relation_proxy(:role=>'news', :ignore_source=>true)
    assert_kind_of Relation, relation
  end
  
  def test_relation_proxy_new_node
    node = secure(Node) { Node.new }
    assert relation = node.relation_proxy(:role=>'blog', :ignore_source=>true)
    assert_equal relations_id(:post_has_blogs), relation[:id]
  end
  
  def test_bad_attribute_raises
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_nothing_raised (NoMethodError) { node.update_attributes( 'tralala_ids' => ['33'])}
    assert node.errors['tralala']
    assert_raise (NoMethodError) { node.update_attributes( 'some_bad_method_name' => ['33'])}
    assert_raise (NoMethodError) { node.some_bad_method_name }
  end
  
  def test_relations_for_form
    login(:tiger)
    {
      Note    => ["blog", "calendar", "favorite_for", "home_for", "hot_for", "icon", "reference", "reference_for", "tag"],
      Image   => ["favorite_for", "home_for", "hot_for", "icon", "icon_for", "reference", "reference_for", "tag"],
      Project => ["added_note", "collaborator", "favorite_for", "home", "home_for", "hot", "hot_for", "icon", "news", "reference", "reference_for", "tag"],
      Contact => ["collaborator_for", "favorite", "favorite_for", "home_for", "hot_for", "icon", "reference", "reference_for", "tag"],
    }.each do |klass, roles|
      node = secure(klass) { klass.find(:first) }
      assert_equal roles, node.relations_for_form.map{|a,b| a}
    end
  end
  
  def test_destroy_links
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:art), node.find(:first, 'tags')[:id]
    assert node.remove_link(links_id(:cleanWater_in_art))
    assert node.save
    assert_nil node.find(:first, 'tags')
  end
  
  def test_relation_new_record
    login(:tiger)
    node = secure(Node) { Node.new }
    assert_equal nil, node.find(:all,'tags')
    node = secure(Node) { Node.get_class('Tag').new_instance }
    assert_equal nil, node.find(:all,'tag_for')
  end

  def test_build_find_class
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.kpath LIKE 'NN%' AND nodes.parent_id = \#{var8[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['notes'], :node_name=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:opening)], res.map{|r| r[:id]}
  end
  
  def test_build_find_class_from_site
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.kpath LIKE 'NN%' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['notes from site'], :node_name=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:letter), nodes_id(:opening), nodes_id(:proposition)], res.map{|r| r[:id]}
  end
  
  def test_build_find_vclass_from_project
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.kpath LIKE 'NNP%' AND nodes.project_id = \#{var8.get_project_id} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['posts from project'], :node_name=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:opening)], res.map{|r| r[:id]}
  end
  
  def test_build_find_vclass_from_project_or_class
    login(:lion)
    assert_equal "SELECT nodes.* FROM nodes   WHERE (((nodes.kpath LIKE 'NNP%' AND nodes.project_id = \#{var8.get_project_id}) OR (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.parent_id = \#{var8[:id]})) AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['posts from project','pages'], :node_name=>'var8')

    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas, :opening, :status, :tracker].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_bad_vclass_from_project
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.id IS NULL AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['badclass from project'], :node_name=>'var8')

    var8 = secure(Node) { nodes(:cleanWater) }
    assert_nil var8.do_find(:all, eval("\"#{str}\""))
  end
  
  def test_build_find_relation
    assert_equal "SELECT nodes.*, lk1.id AS link_id FROM nodes  LEFT JOIN links AS lk1 ON lk1.target_id = nodes.id WHERE (lk1.relation_id = 9 AND lk1.source_id = \#{var8[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['favorites'], :node_name=>'var8')
    
    login(:ant)
    var8 = secure(Node) { nodes(:ant) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:nature].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end

  def test_build_find_relation_with_class
    assert_equal "SELECT nodes.*, lk1.id AS link_id FROM nodes  LEFT JOIN links AS lk1 ON lk1.source_id = nodes.id WHERE (((nodes.kpath LIKE 'NPDI%' AND nodes.parent_id = \#{var8[:id]}) OR (lk1.relation_id = 1 AND lk1.target_id = \#{var8[:id]})) AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['images','news'], :node_name=>'var8')
    login(:ant)
    var8 = secure(Node) { nodes(:wiki) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bird_jpg, :flower_jpg, :opening].map{|s| nodes_id(s)}, res.map{|r| r[:id]}    
  end

  def test_build_find_with_dyn_attribute_clause
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) INNER JOIN dyn_attributes AS da1 ON da1.owner_id = vs.id AND da1.owner_table = 'versions' WHERE (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.section_id = \#{var8.get_section_id} AND da1.key = 'assigned' AND da1.value = 'gaspard' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['pages from section where d_assigned = "gaspard"'], :node_name=>'var8')
    login(:ant)
    var8 = secure(Node) { nodes(:zena) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:cleanWater, :people].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_with_version_clause
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) WHERE (nodes.kpath LIKE 'NP%' AND kpath NOT LIKE 'NPD%' AND nodes.project_id = \#{var8.get_project_id} AND vs.comment = 'no comment yet' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['pages from project where v_comment = "no comment yet"'], :node_name=>'var8')
    login(:lion)
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas, :strange].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_with_version_clause_year
    assert_equal "SELECT nodes.* FROM nodes  INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= 30 AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > 30) WHERE (1 AND nodes.project_id = \#{var8.get_project_id} AND year(vs.updated_at) = '2007' AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC",
      str = Node.build_find(:all, :relations=>['nodes from project where v_updated_at:year = 2007'], :node_name=>'var8')
    login(:lion)
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bananas].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_class_from_site_with_conditions
    login(:tiger)
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.kpath LIKE 'NN%' AND user_id = \#{visitor[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['notes from site'], :node_name=>'var8', :conditions=>"user_id = \#{visitor[:id]}")
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [nodes_id(:letter), nodes_id(:opening)], res.map{|r| r[:id]}
  end
  
  def test_build_find_tags
    login(:tiger)
    assert_equal "SELECT nodes.*, lk1.id AS link_id FROM nodes  LEFT JOIN links AS lk1 ON lk1.target_id = nodes.id WHERE (lk1.relation_id = 2 AND lk1.source_id = \#{var8[:id]} AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", 
      str = Node.build_find(:all, :relations=>['tags'], :node_name=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:art].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_tags_conditions
    login(:tiger)
    str = Node.build_find(:all, :relations=>['images from site'], :node_name=>'var8', :conditions=>["name like ?", "bi%"])
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:all, eval("\"#{str}\""))
    assert_equal [:bird_jpg].map{|s| nodes_id(s)}, res.map{|r| r[:id]}
  end
  
  def test_build_find_root
    login(:tiger)
    assert_equal "SELECT nodes.* FROM nodes   WHERE (nodes.id = 1 AND (nodes.user_id = '\#{visitor[:id]}' OR (rgroup_id IN (\#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = \#{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC LIMIT 1", 
      str = Node.build_find(:first, :relations=>['root'], :node_name=>'var8')
    
    var8 = secure(Node) { nodes(:cleanWater) }
    res  = var8.do_find(:first, eval("\"#{str}\""))
    assert_equal nodes_id(:zena), res[:id]
  end
  
  def test_pages
    login(:ant)
    page = secure(Node) { nodes(:cleanWater) }
    pages = page.find(:all, 'pages')
    assert_equal 2, pages.size
    assert_equal nodes_id(:status), pages[0][:id]
  end
  
  def test_documents
    login(:ant)
    page = secure(Node) { nodes(:cleanWater) }
    documents = page.find(:all, 'documents')
    assert_equal 2, documents.size
    assert_equal nodes_id(:lake_jpg), documents[0][:id]
  end
  
  def test_documents_images_only
    login(:tiger)
    bird = secure(Node) { nodes(:bird_jpg) }
    bird[:parent_id] = nodes_id(:cleanWater)
    assert bird.save
    page = secure(Node) { nodes(:cleanWater) }
    doconly   = page.find(:all, 'documents_only')
    images    = page.find(:all, 'images')
    assert_equal 1, doconly.size
    assert_equal nodes(:water_pdf)[:id], doconly[0][:id]
    assert_equal 2, images.size
    assert_equal nodes(:bird_jpg)[:id], images[0][:id]
  end
  
  def test_link_id
    login(:tiger)
    page = secure(Node) { nodes(:cleanWater) }
    pages = page.find(:all, 'pages')
    assert_nil pages[0][:link_id]
    tags  = page.find(:all, 'tags')
    assert_equal [links_id(:cleanWater_in_art).to_s], tags.map{|r| r[:link_id]}
  end
  
  def test_do_find_in_new_node
    login(:tiger)
    assert var1_new = secure(Node) { Node.get_class("Post").new }
    assert list = var1_new.do_find(:all, "SELECT nodes.* FROM nodes WHERE (nodes.kpath LIKE 'NNP%' AND (nodes.user_id = '#{visitor[:id]}' OR (rgroup_id IN (#{visitor.group_ids.join(',')}) AND nodes.publish_from <= now() ) OR (pgroup_id IN (#{visitor.group_ids.join(',')}) AND max_status > 30)) AND nodes.site_id = #{visitor.site[:id]})  GROUP BY nodes.id  ORDER BY position ASC, name ASC", true)
    assert_equal 2, list.size
    assert_equal [nodes_id(:proposition), nodes_id(:opening)], list.map{|r| r[:id]}.sort
  end
  
  def test_update_attributes_empty_value
    login(:lion)
    node = secure(Node) { nodes(:proposition) }
    assert node.update_attributes_with_transformation("klass"=>"Post", "icon_id"=>"", "v_title"=>"blah", "log_at"=>"2008-02-05 17:33", "parent_id"=>"11")
  end
end
