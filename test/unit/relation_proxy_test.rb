require File.dirname(__FILE__) + '/../test_helper'

class RelationProxyTest < ZenaTestUnit
  
  def test_find_by_role
    assert_equal relations_id(:note_has_calendars), RelationProxy.find_by_role('news')[:id]
    assert_equal relations_id(:note_has_calendars), RelationProxy.find_by_role('calendar')[:id]
    assert_nil RelationProxy.find_by_role('badrole')
  end
  
  def test_get_proxy
    proj = secure(Node) { nodes(:cleanWater) }
    note = secure(Note) { nodes(:opening)    }
    page = secure(Page) { nodes(:status)     }
    assert_equal relations_id(:note_has_calendars), RelationProxy.get_proxy(proj,'news')[:id]
    assert_equal relations_id(:note_has_calendars), RelationProxy.get_proxy(note,'calendar')[:id]
    assert_nil RelationProxy.get_proxy(note, 'badrole')
    assert_nil RelationProxy.get_proxy(note, 'news')
    assert_nil RelationProxy.get_proxy(page, 'calendar')
  end
  
  def test_other_links
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:opening_in_news,:opening_in_art].map{|s| links_id(s)}.sort, rel.other_links.map{|r| r[:id]}.sort
  end
  
  def test_other_id
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    rel  = node.relation_proxy('icon')
    assert_equal nodes_id(:lake_jpg), rel.other_id
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
  
  def test_other_zips
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:news,:art].map{|s| nodes_zip(s)}.sort, rel.other_zips.sort
  end
  
  def test_records
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    rel  = node.relation_proxy('set_tag')
    assert_equal [:art,:news].map{|s| nodes_id(s)}, rel.records.map{|r| r[:id]}
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
  
  def test_set_tag_ids
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
    assert node.relation_proxy('hot_for')
    assert node.relation_proxy('set_tags')
    assert_nil node.relation_proxy('hot')
    node = secure!(Node) { nodes(:cleanWater) }
    assert node.relation_proxy('hot_for')
    assert rel = node.relation_proxy('hot')
    assert_kind_of RelationProxy, rel
  end
  
  def test_relation_proxy_new_node
    node = secure!(Node) { Node.new_from_class('Post') }
    assert rel = node.relation_proxy('blog')
    assert_equal relations_id(:post_has_blogs), rel[:id]
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
