require File.dirname(__FILE__) + '/../test_helper'

class RelationProxyTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  
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
    
    # Any new node can have a relation_proxy (used when forms contain the 'klass' attribute selected by the user).
    node = secure!(Node) { Node.new_from_class('Node') }
    assert rel = node.relation_proxy('blog')
    assert_equal relations_id(:post_has_blogs), rel[:id]
  end
  
  def test_bad_attribute_raises
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_nothing_raised (NoMethodError) { node.update_attributes( 'tralala_ids' => ['33'])}
    assert node.errors['tralala']
    assert_equal Hash[], node.remove_attributes_with_same_value( 'some_bad_method_name' => ['33'])
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
  
  def test_remove_link
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:art), node.find(:first, 'set_tags')[:id]
    assert node.remove_link(links(:cleanWater_in_art))
    assert node.save
    assert_nil node.find(:first, 'set_tags')
  end
  
  def test_update_attributes_empty_value
    login(:lion)
    node = secure!(Node) { nodes(:proposition) }
    assert node.update_attributes_with_transformation("klass"=>"Post", "icon_id"=>"", "v_title"=>"blah", "log_at"=>"2008-02-05 17:33", "parent_id"=>"11")
  end
  
  def test_update_comment
    login(:lion) # status_hot_for_cleanWater
    node = secure!(Node) { nodes(:cleanWater) }
    hot  = node.find(:first, 'hot')
    assert_equal nodes_id(:status), hot[:id] 
    assert_nil hot.l_status
    assert node.update_attributes('hot_comment' => 'very hot')
    # reload
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal 'very hot', node.find(:first, 'hot').l_comment
  end
  
  def test_update_comment_in_group
    login(:lion) # status_hot_for_cleanWater
    node = secure!(Node) { nodes(:opening) }
    tags = node.find(:all, 'set_tags')
    assert_equal 2, tags.size
    art = tags[0]
    assert_equal 5, art.l_status
    node.update_attributes('set_tag_status' => 123, 'set_tag_id' => nodes_id(:art))
    # reload
    node = secure!(Node) { nodes(:opening) }
    tags = node.find(:all, 'set_tags')
    art = tags[0]
    assert_equal 123, art.l_status
  end
  
  def test_update_l_comment
    login(:lion) # status_hot_for_cleanWater
    node = secure!(Node) { nodes(:cleanWater) }
    hot  = node.find(:first, 'hot')
    assert_equal nodes_id(:status), hot[:id] 
    assert_nil hot.l_status
    node.update_attributes(:link_id => links_id(:status_hot_for_cleanWater), :l_comment => 'very hot')
    err node
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
  
  def test_add_link_bad_target
    login(:lion)
    node = secure!(Node) { nodes(:letter) }
    node.add_link('calendar', :id => 1)
    assert !node.save
    assert_equal 'invalid target', node.errors['calendar']
    
    node = secure!(Node) { nodes(:letter) }
    node.add_link('calendar', :id => 1, :comment => 'woopi')
    assert !node.save
    assert_equal 'invalid target', node.errors['calendar']
    
    node = secure!(Node) { nodes(:letter) }
    node.add_link('calendar', :id => nil, :comment => 'woopi')
    assert !node.save
    assert_equal 'invalid target', node.errors['calendar']
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
    link.update_attributes_with_transformations('status' => 12345)
    err link
    # reload
    icon_for = secure!(Node) { nodes(:flower_jpg) }.find(:all, 'icon_for')
    assert_equal 2, icon_for.size
    lion_as_icon_for = icon_for[0]
    assert_equal nodes_id(:lion), lion_as_icon_for[:id]
    assert_equal 12345, lion_as_icon_for.l_status
  end
  
  def test_update_status
    login(:lion)
    node = secure!(Node) { nodes(:cleanWater) }
    assert hot = node.find(:first, 'hot')
    assert_nil hot.l_status
    assert node.update_attributes_with_transformation('hot_status' => 33)
    node = secure!(Node) { nodes(:cleanWater) }
    assert hot = node.find(:first, 'hot')
    assert_equal 33, hot.l_status
  end
  
  def test_create_invalid_target_empty
    login(:lion)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:cleanWater),'klass'=>'Page', 'foo_id'=>'342', 'v_title'=>'hello') }
    assert node.new_record?
    assert_equal 'invalid relation', node.errors['foo']
    # invalid relation
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:cleanWater),'klass'=>'Page', 'foo_id'=>'', 'v_title'=>'one') }
    assert !node.new_record?
    # invalid target
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:cleanWater),'klass'=>'Page', 'icon_id'=>'', 'v_title'=>'two') }
    assert !node.new_record?
  end
end
