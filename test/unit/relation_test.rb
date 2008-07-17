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
    node = secure!(Node) { nodes(:opening) }
    assert calendars = node.find(:all, 'calendars')
    assert_equal 2, calendars.size
    calendars.each do |obj|
      assert_kind_of Project, obj
    end
    assert calendars = node.find(:all, ['calendars'])
    assert_equal 2, calendars.size
    calendars.each do |obj|
      assert_kind_of Project, obj
    end
  end
  
  def test_find
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'cleanWater', node.find(:first,'parent')[:name]
    assert_equal 'projects', node.find(:first,'parent').find(:first,'parent')[:name]
    assert_equal 'zena', node.find(:first,'root')[:name]
    assert_equal 'art', node.find(:first,'parent').find(:all,'set_tags')[0][:name]
  end
  
  def test_set_relation
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.set_relation('set_tag',[nodes_id(:art).to_s])
    assert node.save
    node = secure!(Node) { nodes(:status) } # reload
    assert_equal nodes_id(:art), node.find(:all,'set_tags')[0][:id]
  end

  def test_remove_link
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    assert calendars = node.find(:all,'calendars')
    assert_equal 2, calendars.size
    node.remove_link(links_id(:opening_in_zena))
    assert node.save
    node = secure!(Node) { nodes(:opening) } # reload
    assert calendars = node.find(:all,'calendars')
    assert_equal 1, calendars.size
  end
  
  def test_add_link
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.find(:all,'set_tags')
    node.add_link('set_tag', :id => nodes_id(:art), :comment => "hello")
    assert node.save
    node = secure!(Node) { nodes(:status) } # reload
    assert tags = node.find(:all,'set_tags')
    assert_equal 1, tags.size
    assert_equal nodes_id(:art), tags[0][:id]
    assert_equal "hello", tags[0][:l_comment]
  end
  
  def test_add_link_virtual_class
    login(:tiger)
    node = secure!(Node) { nodes(:proposition) } # Post virtual class
    assert_kind_of Relation, node.relation_proxy('blog')
    assert_nil node.find(:all,'blogs')
    node.add_link('blog', nodes_id(:cleanWater))
    assert node.save
    node = secure!(Node) { nodes(:proposition) } # reload
    assert blogs = node.find(:all,'blogs')
    assert_equal 1, blogs.size
    assert_equal nodes_id(:cleanWater), blogs[0][:id]
  end
  
  def test_add_link_virtual_class_bad_target
    login(:tiger)
    node = secure!(Node) { nodes(:proposition) } # Post virtual class
    assert_kind_of Relation, node.relation_proxy('blog')
    assert_nil node.find(:all,'blogs')
    node.add_link('blog', nodes_id(:art))
    assert !node.save
    assert_equal 'invalid target', node.errors[:blog]
  end
  
  def test_relation_links
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    assert_equal [[relations_id(:post_has_blogs),     [nodes_id(:zena)]], 
                  [relations_id(:note_has_calendars), [nodes_id(:wiki), nodes_id(:zena)].sort], 
                  [relations_id(:node_has_tags),      [nodes_id(:art),  nodes_id(:news)].sort]
                  ].sort{|a,b| a[0] <=> b[0]}, 
                  
                  node.relation_links.map{|r,l| [r.id, l.map{|r| r.id}.sort]}.sort{|a,b| a[0] <=> b[0]}
  end
  
  def test_ant_favorites
    login(:ant)
    ant = secure!(User) { users(:ant) }
    assert_equal 1, ant.contact.find(:all,'favorites').size
  end
  
  def test_other_links
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:opening_in_news,:opening_in_art].map{|s| links_id(s)}.sort, rel.other_links.map{|r| r[:id]}.sort
  end
  
  def test_other_ids
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:news,:art].map{|s| nodes_id(s)}.sort, rel.other_ids.sort
  end
  
  def test_other_zip
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_zip(:lake_jpg), node.send('icon_zip')
  end
  
  def test_records
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:art,:news].map{|s| nodes_id(s)}, rel.records.map{|r| r[:id]}
  end
  
  def test_set_relation_method_missing
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes( 'set_tag_ids' => [nodes_id(:art).to_s] )
    assert_equal [nodes_id(:art)], node.set_tag_ids
    node = secure!(Node) { nodes(:status) } # reload
    assert_equal nodes_id(:art), node.find(:all,'set_tags')[0][:id]
    assert_equal [nodes_id(:art)], node.set_tag_ids
    assert_equal [nodes_zip(:art)], node.set_tag_zips
  end
  
  def test_relation_proxy
    node = secure!(Node) { nodes(:status) }
    assert relation = node.relation_proxy('hot_for')
    assert relation = node.relation_proxy('set_tags')
    assert_nil node.relation_proxy('hot')
    node = secure!(Node) { nodes(:cleanWater) }
    assert relation = node.relation_proxy('hot_for')
    assert relation = node.relation_proxy('hot')
    assert relation = node.relation_proxy(:role=>'news', :ignore_source=>true)
    assert_kind_of Relation, relation
  end
  
  def test_relation_proxy_new_node
    node = secure!(Node) { Node.new }
    assert relation = node.relation_proxy(:role=>'blog', :ignore_source=>true)
    assert_equal relations_id(:post_has_blogs), relation[:id]
  end
  
  def test_bad_attribute_raises
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_nothing_raised (NoMethodError) { node.update_attributes( 'tralala_ids' => ['33'])}
    assert node.errors['tralala']
    assert_raise (NoMethodError) { node.update_attributes( 'some_bad_method_name' => ['33'])}
    assert_raise (NoMethodError) { node.some_bad_method_name }
  end
  
  def test_relations_for_form
    login(:tiger)
    {
      Note    => ["blog", "calendar", "favorite_for", "home_for", "hot_for", "icon", "reference", "reference_for", "set_tag"],
      Image   => ["favorite_for", "home_for", "hot_for", "icon", "icon_for", "reference", "reference_for", "set_tag"],
      Project => ["added_note", "collaborator", "favorite_for", "home", "home_for", "hot", "hot_for", "icon", "news", "reference", "reference_for", "set_tag"],
      Contact => ["collaborator_for", "favorite", "favorite_for", "home_for", "hot_for", "icon", "reference", "reference_for", "set_tag"],
    }.each do |klass, roles|
      node = secure!(klass) { klass.find(:first) }
      assert_equal roles, node.relations_for_form.map{|a,b| a}
    end
  end
  
  def test_destroy_links
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:art), node.find(:first, 'set_tags')[:id]
    assert node.remove_link(links_id(:cleanWater_in_art))
    assert node.save
    assert_nil node.find(:first, 'set_tags')
  end
  
  def test_relation_new_record
    login(:tiger)
    node = secure!(Node) { Node.new }
    assert_equal nil, node.find(:all,'set_tags')
    node = secure!(Node) { Node.get_class('Tag').new_instance }
    assert_equal nil, node.find(:all,'tagged')
  end

  def test_link_id
    login(:tiger)
    page = secure!(Node) { nodes(:cleanWater) }
    pages = page.find(:all, 'pages')
    assert_nil pages[0][:link_id]
    tags  = page.find(:all, 'set_tags')
    assert_equal [links_id(:cleanWater_in_art).to_s], tags.map{|r| r[:link_id]}
  end
  
  def test_do_find_in_new_node
    login(:tiger)
    assert var1_new = secure!(Node) { Node.get_class("Post").new }
    assert_nil var1_new.do_find(:all, eval("\"#{Node.build_find(:all, 'posts in site', :node_name => 'self')}\""))
  end
  
  def test_update_attributes_empty_value
    login(:lion)
    node = secure!(Node) { nodes(:proposition) }
    assert node.update_attributes_with_transformation("klass"=>"Post", "icon_id"=>"", "v_title"=>"blah", "log_at"=>"2008-02-05 17:33", "parent_id"=>"11")
  end
  
  def test_do_find_bad_relation
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.find(:first, 'blah')
  end
  
  def test_l_status
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    tagged = node.find(:all, 'tagged')
    # cleanWater, opening
    assert_equal [10, 5], tagged.map{|t| t.l_status}
  end
  
  def test_l_comment
    login(:lion)
    node = secure!(Node) { nodes(:opening) }
    tagged = node.find(:all, 'set_tags')
    # art, news
    assert_equal ["cold", "hot"], tagged.map{|t| t.l_comment}
  end
  
  def test_l_comment_empty
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    tagged = node.find(:all, 'tagged')
    # cleanWater, opening
    assert_equal [nil, "cold"], tagged.map{|t| t.l_comment}
  end
  
  def test_update_link
    login(:lion) # status_hot_for_cleanWater
    node = secure!(Node) { nodes(:cleanWater) }
    hot  = node.find(:first, 'hot')
    assert_equal nodes_id(:status), hot[:id] 
    assert_nil hot.l_status
    node.update_link('hot', :id => nodes_id(:status), :comment => 'very hot')
    assert node.save
    # reload
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal 'very hot', node.find(:first, 'hot').l_comment
  end
  
  def test_update_l_comment
    login(:lion) # status_hot_for_cleanWater
    node = secure!(Node) { nodes(:cleanWater) }
    hot  = node.find(:first, 'hot')
    assert_equal nodes_id(:status), hot[:id] 
    assert_nil hot.l_status
    node.update_attributes(:link_id => links_id(:status_hot_for_cleanWater), :l_comment => 'very hot')
    assert node.save
    # reload
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal 'very hot', node.find(:first, 'hot').l_comment
    # modify again
    node.update_attributes(:link_id => links_id(:status_hot_for_cleanWater), :l_comment => 'very hot', :l_status => '45')
    assert node.save
    # reload
    hot  = node.find(:first, 'hot')
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal 'very hot', hot.l_comment
    assert_equal 45,         hot.l_status
  end
  
  def test_add_link_target_as_unique
    # from 'icons' set 'icon_for' many times on same node
    login(:lion)
    bird   = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    
    assert bird.update_attributes(:icon_for_id => nodes_id(:status) )
    icons = secure!(Node) { nodes(:status) }.find(:all, 'icon')
    assert_equal 1, icons.size
    assert_equal bird[:id], icons[0][:id]
    
    assert flower.update_attributes(:icon_for_id => nodes_id(:status) )
    icons = secure!(Node) { nodes(:status) }.find(:all, 'icon')
    assert_equal 1, icons.size
    assert_equal flower[:id], icons[0][:id]
  end
  
  
  def test_set_link_many_targets
    # set icon_for on many nodes, one at a time
    login(:lion)
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert flower.update_attributes(:icon_for_id => nodes_id(:status) )
    assert flower.update_attributes(:icon_for_id => nodes_id(:lion) )
    icons = secure!(Node) { nodes(:status) }.find(:all, 'icon')
    assert_equal flower[:id], icons[0][:id]
    icons = secure!(Node) { nodes(:lion) }.find(:all, 'icon')
    assert_equal flower[:id], icons[0][:id]
  end
  
  def test_update_link_status_many_targets
    # set icon_for on many nodes, one at a time
    login(:lion)
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert flower.update_attributes(:icon_for_id => nodes_id(:status) )
    assert flower.update_attributes(:icon_for_id => nodes_id(:lion) )
    icon_for = secure!(Node) { nodes(:flower_jpg) }.find(:all, 'icon_for')
    assert_equal 2, icon_for.size
    lion_as_icon_for = icon_for[0]
    assert_equal nodes_id(:lion), lion_as_icon_for[:id]
    assert_nil lion_as_icon_for.l_status
    link = Link.find_through(flower, lion_as_icon_for.link_id)
    assert link.update_attributes_with_transformations('status' => 12345)
    
    # reload
    icon_for = secure!(Node) { nodes(:flower_jpg) }.find(:all, 'icon_for')
    assert_equal 2, icon_for.size
    lion_as_icon_for = icon_for[0]
    assert_equal nodes_id(:lion), lion_as_icon_for[:id]
    assert_equal 12345, lion_as_icon_for.l_status
  end
  
  # Fixing this is not a priority. Refs #196.
  #def test_update_status
  #  login(:lion)
  #  node = secure!(Node) { nodes(:cleanWater) }
  #  assert hot = node.find(:first, 'hot')
  #  assert_nil hot.l_status
  #  assert node.update_attributes_with_transformation('hot_status' => 33)
  #  node = secure!(Node) { nodes(:cleanWater) }
  #  assert hot = node.find(:first, 'hot')
  #  assert_equal 33, hot.l_status
  #end
end
