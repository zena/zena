require File.dirname(__FILE__) + '/../test_helper'

class NodeTest < ZenaTestUnit

  NEW_DEFAULT = {
    :name => 'hello',
    :rgroup_id => 1,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => 1,
    :project_id => 1,
  }
  
  def test_find_by_path
    login(:ant)
    node = nodes(:wiki)
    assert_nil node[:fullpath]
    node = secure(Node) { Node.find_by_path('projects/wiki') }
    assert_equal 'projects/wiki', node.fullpath
    node = secure(Node) { Node.find_by_path('projects/wiki') }
    assert_equal 'projects/wiki', node[:fullpath]
  end
  
  def test_get_fullpath
    login(:ant)
    node = secure(Node) { nodes(:lake)  }
    parent = node.parent
    assert_nil parent[:fullpath]
    assert_nil node[:fullpath]
    assert_equal 'projects/cleanWater/lake', node.fullpath
    node.reload
    assert_equal 'projects/cleanWater/lake', node[:fullpath]
    parent.reload
    assert_equal 'projects/cleanWater', parent[:fullpath]
  end
  
  def test_get_fullpath_after_private
    Node.connection.execute "UPDATE nodes SET parent_id = 3 WHERE id = 12" # put 'status' page inside private 'ant' page
    node = nil
    login(:tiger)
    assert_nothing_raised { node = secure(Node) { nodes(:status) } }
    assert_kind_of Node, node
    assert_raises (ActiveRecord::RecordNotFound) { node = secure(Node) { Node.find_by_path('people/ant') } }
    assert_nothing_raised { node = secure(Node) { Node.find_by_path('people/ant/status')}}
  end
  
  def test_rootpath
    login(:ant)
    node = secure(Node) { nodes(:status) }
    assert_equal 'zena/projects/cleanWater/status', node.rootpath
    node = secure(Node) { nodes(:zena) }
    assert_equal 'zena', node.rootpath
  end
  
  def test_basepath
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_equal 'projects/cleanWater', node.basepath
    node = secure(Node) { nodes(:projects) }
    assert_equal '', node.basepath
    node = secure(Node) { nodes(:proposition) }
    assert_equal '', node.basepath
  end
  
  def test_ancestors
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:proposition)} WHERE id = 20" # put 'bird' page inside note 'proposition' page
    login(:ant)
    node = secure(Node) { nodes(:status) }
    assert_equal ['zena', 'projects', 'cleanWater'], node.ancestors.map { |a| a[:name] }
    node = secure(Node) { nodes(:zena) }
    assert_equal [], node.ancestors
    node = secure(Node) { nodes(:bird_jpg) }
    prop = secure(Node) { nodes(:proposition)}
    assert_kind_of Node, prop
    assert prop.can_read?
    assert_equal ['zena', 'projects', 'proposition'], node.ancestors.map { |a| a[:name] }
  end
  
  def test_root
    login(:ant)
    node = secure(Node) { nodes(:status) }
    root = node.root
    assert_equal 'zena', root[:name]
  end
  
  def test_relation
    login(:ant)
    node = secure(Node) { nodes(:status) }
    assert_equal 'cleanWater', node.relation('parent')[:name]
    assert_equal 'projects', node.relation('parent').relation('parent')[:name]
    assert_equal 'zena', node.relation('root')[:name]
    assert_equal 'art', node.relation('parent').relation('tags')[0][:name]
  end
  
  def test_ancestor_in_hidden_project
    login(:ant)
    node = secure(Node) { nodes(:proposition) }
    assert_kind_of Node, node
    assert_equal ['zena', 'projects'], node.ancestors.map { |a| a[:name] } # ant can view 'proposition' but not the project proposition is in
  end
  
  def test_create_simplest
    login(:ant)
    test_page = secure(Node) { Node.create(:name=>"yoba", :parent_id=>nodes_id(:cleanWater), :inherit=>1 ) }
    assert ! test_page.new_record? , "Not a new record"
  end
  
  def test_new_bad_parent
    login(:tiger)
    attrs = NEW_DEFAULT
    attrs[:parent_id] = nodes(:proposition).id
    node = secure(Page) { Page.new(attrs) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", node.errors[:parent_id] # parent cannot be 'Note' if self not Document

    attrs[:parent_id] = nodes(:myDreams).id # cannot write here
    node = secure(Page) { Page.new(attrs) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]

    attrs[:parent_id] = nodes(:cleanWater).id # parent ok
    node = secure(Page) { Page.new(attrs) }
    assert node.save , "Save succeeds"
  end
  
  def test_new_without_parent
    login(:tiger)
    attrs = NEW_DEFAULT
    attrs.delete(:parent_id)
    node = secure(Node) { Node.new(attrs) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]
    # page parent ok
    assert node.new_record?
    node = secure(Node) { Node.new(attrs) }
    node.parent_id = nodes_id(:lake)
    assert node.save , "Save succeeds"
  end
  
  def test_page_new_without_name
    login(:tiger)
    node = secure(Node) { Node.new(:parent_id=>1) }
    assert ! node.save, 'Save fails'
    assert_equal "can't be blank", node.errors[:name]
  end
  
  def test_new_set_project_id
    login(:tiger)
    node = secure(Page) { Page.create(:parent_id=>nodes_id(:status), :name=>'SuperPage')}
    assert ! node.new_record?, 'Not a new record'
    assert_equal nodes_id(:cleanWater), node[:project_id]
  end
  
  def test_update_no_or_bad_parent
    login(:ant)
    node = secure(Node) { nodes(:wiki) }
    assert_kind_of Node, node
    assert node.save , "Save succeeds"
    node.parent_id = nil
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    node = secure(Node) { nodes(:wiki) }
    node.parent_id = nodes_id(:wiki)
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    node = secure(Node) { nodes(:wiki) }
    node.parent_id = nodes_id(:cleanWater)
    assert ! node.save , "Save fails"
  end
  
  def test_update_bad_parent
    login(:tiger)
    node = secure(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:proposition)
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", node.errors[:parent_id] # parent cannot be 'Note' if self not Document
    
    node = secure(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:myDreams) # cannot write here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]
    
    node = secure(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:projects) # parent ok
    assert node.save , "Save succeeds"
  end
  
  def test_page_update_without_name
    login(:tiger)
    node = secure(Node) { nodes(:status)  }
    node[:name] = nil
    assert node.save, 'Save succeeds'
    assert_equal 'statusTitle', node[:name]
    node = secure(Node) { nodes(:status)  }
    node[:name] = nil
    node.v_title = ""
    assert !node.save, 'Save fails'
    assert_equal node.errors[:name], "can't be blank"
  end
  
  def test_update_set_project_id
    login(:tiger)
    node = secure(Page) { Page.find(nodes_id(:status))}
    assert_equal nodes_id(:cleanWater), node[:project_id]
    node[:parent_id]  = nodes_id(:zena)
    node[:project_id] = nodes_id(:status)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:zena), node[:project_id]
  end
  
  def test_create_same_name
    login(:tiger)
    node = secure(Node) { Node.create(:parent_id=>nodes(:wiki)[:parent_id], :name=>'wiki')}
    assert node.new_record?
    assert_equal node.errors[:name], 'has already been taken'
  end
  
  def test_create_same_name_other_parent
    login(:tiger)
    node = secure(Node) { Node.create(:parent_id=>1, :name=>'wiki')}
    assert ! node.new_record?, 'Not a new record'
    assert_nil node.errors[:name]
  end

  def test_update_same_name
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    node.name = 'wiki'
    assert ! node.save, 'Cannot save'
    assert_equal node.errors[:name], 'has already been taken'
  end

  def test_update_same_name_other_parent
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    node.name = 'wiki'
    node[:parent_id] = 1
    node.save
    err(node)
    assert node.save
    assert_nil node.errors[:name]
  end
  
  def test_before_destroy
    login(:tiger)
    node = secure(Node) { nodes(:projects)  }
    assert !node.destroy, "Cannot destroy"
    assert_equal node.errors[:base], 'contains subpages'
    node = secure(Node) { nodes(:status)  }
    assert node.destroy, "Can destroy"
  end
  
  def test_cannot_destroy_has_private
    login(:tiger)
    node = secure(Node) { nodes(:lion)  }
    assert_equal 0, node.pages.size # cannot see subpages
    assert !node.destroy, "Cannot destroy"
    assert_equal node.errors[:base], 'contains subpages'
  end
  
  def test_list_children
    login(:ant)
    
    page = secure(Node) { nodes(:projects)  }
    children = page.children
    assert_equal 2, children.size
    
    login(:tiger)
    page = secure(Node) { nodes(:projects)  }
    children = page.children
    assert_equal 3, children.size
    assert_equal 3, page.children.size
  end
  
  def test_parent
    assert_equal nodes_id(:projects), secure(Node) { nodes(:wiki) }.parent[:id]
  end
  
  def test_project
    assert_equal nodes_id(:zena), secure(Node) { nodes(:people) }.project[:id]
  end
  
  def test_pages
    login(:ant)
    page = secure(Node) { nodes(:cleanWater) }
    pages = page.pages
    assert_equal 3, pages.size
    assert_equal nodes(:lake)[:id], pages[0][:id]
  end
  
  def test_documents
    login(:ant)
    page = secure(Node) { nodes(:cleanWater) }
    documents = page.documents
    assert_equal 1, documents.size
    assert_equal nodes(:water_pdf)[:id], documents[0][:id]
  end
  
  def test_documents_images_only
    login(:tiger)
    bird = secure(Node) { nodes(:bird_jpg) }
    bird[:parent_id] = nodes_id(:cleanWater)
    assert bird.save
    page = secure(Node) { nodes(:cleanWater) }
    doconly   = page.documents_only
    images    = page.images
    assert_equal 1, doconly.size
    assert_equal nodes(:water_pdf)[:id], doconly[0][:id]
    assert_equal 1, images.size
    assert_equal nodes(:bird_jpg)[:id], images[0][:id]
  end
  
  def test_notes
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    notes = node.notes
    assert_equal 1, notes.size
    assert_equal 'opening', notes[0][:name]
  end
  
  def test_trackers
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    trackers = node.trackers
    assert_equal 1, trackers.size
    assert_equal 'track', trackers[0][:name]
  end
  
  def test_new_child
    login(:ant)
    node = secure(Node) { nodes(:cleanWater)  }
    child = node.new_child( :name => 'lake' )
    assert ! child.save , "Save fails"
    assert child.errors[:name] , "Errors on name"
  
    child = node.new_child( :name => 'new_name' )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.v_status
    assert_equal child[:user_id], users_id(:ant)
    assert_equal node[:pgroup_id], child[:pgroup_id]
    assert_equal node[:rgroup_id], child[:rgroup_id]
    assert_equal node[:wgroup_id], child[:wgroup_id]
    assert_equal node[:project_id], child[:project_id]
    assert_equal 1, child[:inherit]
    assert_equal node[:id], child[:parent_id]
  end
  
  def test_secure_find_by_path
    login(:tiger)
    node = secure(Node) { Node.find_by_path('projects/secret') }
    assert_kind_of Node, node
    login(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { Node.find_by_path('projects/secret') }}
  end
  
  def test_author
    node = nodes(:status)
    assert_equal node.user, node.author
    assert_equal 'ant', node.author.login
  end
  
  def test_ext
    node = nodes(:status)
    node[:name] = 'bob. and bob.jpg'
    assert_equal 'jpg', node.ext
    node[:name] = 'no ext'
    assert_equal '', node.ext
    node[:name] = ''
    assert_equal '', node.ext
    node[:name] = nil
    assert_equal '', node.ext
  end
  
  def test_set_name
    node = nodes(:wiki)
    node.name = " J'aime l'aïl en août ! "
    assert_equal 'JAimeLAilEnAout', node.name
    assert_equal 'JAimeLAilEnAout', node[:name]
    node.name = "LIEUX"
    assert_equal 'LIEUX', node.name
  end
 
  # TESTS FOR CHANGE_TO
  # def test_change_to_page_to_project
  #   login(:tiger)
  #   node = secure(Node) { nodes(:people)  }
  #   id, parent_id, project_id = node[:id], node[:parent_id], node[:project_id]
  #   vers_count = Version.find(:all).size
  #   vers_id = node.v_id
  #   node = node.change_to(Project)
  #   assert_kind_of Project, node
  #   node = secure(Project) { Project.find(nodes_id(:people)) }
  #   assert_kind_of Project, node
  #   assert_equal 'NPP', node[:kpath]
  #   assert_equal id, node[:id]
  #   assert_equal parent_id, node[:parent_id]
  #   assert_equal node[:id], node[:project_id]
  #   assert_equal vers_count, Version.find(:all).size
  #   assert_equal vers_id, node.v_id
  #   assert_equal node[:id], nodes(:ant)[:project_id] # children inherit new project_id
  #   assert_equal node[:id], nodes(:myLife)[:project_id]
  # end
  # 
  # def test_change_project_to_page
  #   login(:tiger)
  #   node = secure(Node) { nodes(:cleanWater)  }
  #   id, parent_id = node[:id], node[:parent_id]
  #   vers_count = Version.find(:all).size
  #   vers_id = node.v_id
  #   node = node.change_to(Page)
  #   assert_kind_of Page, node
  #   node = secure(Page) { Page.find(nodes_id(:cleanWater)) }
  #   assert_kind_of Page, node
  #   assert_equal 'NP', node[:kpath]
  #   assert_equal id, node[:id]
  #   assert_equal parent_id,  node[:parent_id]
  #   assert_equal nodes_id(:zena), node[:project_id]
  #   assert_equal vers_count, Version.find(:all).size
  #   assert_equal vers_id, node.v_id
  #   assert_equal nodes_id(:zena), nodes(:status)[:project_id] # children inherit new project_id
  #   assert_equal nodes_id(:zena), nodes(:lake)[:project_id]
  # end
  # 
  # def test_cannot_change_root
  #   login(:tiger)
  #   node = secure(Node) { Node.find(ZENA_ENV[:root_id]) }
  #   node = node.change_to(Page)
  #   assert_nil node
  #   node = secure(Node) { Node.find(ZENA_ENV[:root_id]) }
  #   assert_kind_of Project, node
  # end
  
  def test_sync_project
    login(:tiger)
    node = secure(Node) { nodes(:projects) }
    node.send(:sync_project, 99)
    assert_equal nodes_id(:cleanWater), nodes(:cleanWater)[:project_id]
    node = secure(Node) { nodes(:people) }
    node.send(:sync_project, 99)
    assert_equal 99, nodes(:ant)[:project_id]
    assert_equal 99, nodes(:myLife)[:project_id]
  end
  
  def test_spread_project_id
    login(:tiger)
    node = secure(Node) { nodes(:people) }
    node.parent_id =   nodes_id(:status) # in project cleanWater
    assert node.save
    assert_equal nodes_id(:cleanWater), node[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:ant)[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:myLife)[:project_id]
  end
  
  def test_after_remove
    Version.connection.execute "UPDATE versions SET user_id=4 WHERE node_id IN (19,20,21)"
    Node.connection.execute "UPDATE nodes SET user_id=4 WHERE id IN (19,20,21)"
    login(:tiger)
    wiki = secure(Node) { nodes(:wiki) }
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], wiki.v_status
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], flower.v_status
    assert wiki.remove, 'Can remove publication'
    assert_equal 10, wiki.v_status
    assert_equal 10, wiki.max_status
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal 10, bird.v_status
    assert_equal 10, flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_propose
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE node_id IN (19,20,21)"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    login(:tiger)
    wiki = secure(Node) { nodes(:wiki) }
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], wiki.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], flower.v_status
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_refuse
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE node_id IN (19,20,21)"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    login(:tiger)
    wiki = secure(Node) { nodes(:wiki) }
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.refuse, 'Can refuse'
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.max_status
    assert_equal Zena::Status[:red], flower.v_status
  end
  
  def test_after_publish
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE node_id IN (19,20,21)"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    login(:tiger)
    wiki = secure(Node) { nodes(:wiki) }
    assert wiki.publish, 'Can publish'
    assert_equal Zena::Status[:pub], wiki.v_status
    bird = secure(Node) { nodes(:bird_jpg) }
    flower = secure(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_all_children
    login(:tiger)
    people_id = nodes_id(:people)
    ant_id = nodes_id(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { secure(Node) { Node.find(ant_id) }  }
    nodes  = secure(Node) { Node.find(people_id).send(:all_children) }
    people = secure(Node) { Node.find(people_id)}
    assert_equal 3, nodes.size
    assert_equal 2, people.children.size
    assert_raise(NoMethodError) { people.all_children }
  end
  
  def test_camelize
    node = nodes(:wiki)
    assert_equal "salutJEcrisAujourdHui", node.send(:camelize,"salut j'écris: Aujourd'hui ")
    assert_equal "aBabMol", node.send(:camelize," à,--/ bab mol")
    assert_equal "07.11.2006Mardi", node.send(:camelize,"07.11.2006-mardi")
  end
  
  def test_tags
    login(:lion)
    @node = secure(Node) { nodes(:status)  }
    assert_nothing_raised { @node.tags }
    assert_equal [], @node.tags
    @node.tag_ids = [nodes_id(:art),nodes_id(:news)]
    assert @node.save
    tags = @node.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @node.tag_ids = [nodes_id(:art)]
    @node.save
    tags = @node.tags
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end
  
  def test_tags_callbacks
    assert Node.read_inheritable_attribute(:after_save).include?(:save_tags)
    assert Page.read_inheritable_attribute(:after_save).include?(:save_tags)
  end
  
  def test_after_all_cache_sweep
    bak = ApplicationController.perform_caching
    ApplicationController.perform_caching = true
    login(:lion)
    i = 1
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    i = 2
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    
    # do something on a document
    node = secure(Node) { nodes(:water_pdf) }
    assert_equal 'NPD', node.class.kpath
    assert node.update_attributes(:v_title=>'new title'), "Can change attributes"
    # sweep only kpath NPD
    i = 3
    assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    
    # do something on a note
    node = secure(Node) { nodes(:proposition) }
    assert_equal 'NN', node.class.kpath
    assert node.update_attributes(:name=>'popo'), "Can change attributes"
    # sweep only kpath NPD
    i = 4
    assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
    assert_equal "content 4", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    
    ApplicationController.perform_caching = bak
  end
  
  def test_empty_comments
    login(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert_equal [], node.comments
  end
  
  def test_discussion_lang
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert_equal discussions_id(:outside_discussion_on_status_en), discussion[:id]
    login(:ant)
    node = secure(Node) { nodes(:status) }
    discussion = node.discussion
    assert discussion.new_record?, "New discussion"
    assert_equal 'fr', discussion.lang
    assert discussion.open?
    assert !discussion.inside?
  end
  
  def test_closed_discussion
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    discussion = node.discussion
    discussion.update_attributes(:open=>false)
    node = secure(Node) { nodes(:status) }
    assert_equal discussions_id(:outside_discussion_on_status_en), node.discussion[:id]
    login(:ant)
    node = secure(Node) { nodes(:status) }
    assert_nil node.discussion
    node.update_attributes( :v_title=>'test' )
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert discussion.inside?
  end
  
  def test_inside_discussion
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    node.update_attributes( :v_title=>'new status' )
    assert_equal Zena::Status[:red], node.v_status
    discussion = node.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end
  
  def test_comments
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    comments = node.comments
    assert_kind_of Comment, comments[0]
    assert_equal 'Nice site', comments[0][:title]
  end
  
  def test_comments_on_nil
    login(:tiger)
    node = secure(Node) { nodes(:cleanWater) }
    assert_nil node.discussion # no open discussion here
    assert_equal [], node.comments
  end
  
  def test_add_comment
    login(:ant)
    visitor.lang = 'en'
    node = secure(Node) { nodes(:status) }
    assert_equal 1, node.comments.size
    assert comment = node.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world' )
    node = secure(Node) { nodes(:status) }
    comments = node.comments
    assert_equal 2, node.comments.size
    assert_equal 'hello', comments[1][:title]
    assert_equal nil, comments[1][:author_name]
  end
  
  def test_anon_add_comment
    aanon = ZENA_ENV[:allow_anonymous_comments]
    manon = ZENA_ENV[:moderate_anonymous_comments]
    node = secure(Node) { nodes(:status) }
    assert_equal 1, node.comments.size
    ZENA_ENV[:allow_anonymous_comments] = false
    assert !node.can_comment?, "Anonymous cannot comment."
    ZENA_ENV[:allow_anonymous_comments] = true
    assert node.can_comment?, "Anonymous can comment."
    ZENA_ENV[:moderate_anonymous_comments] = true
    assert comment = node.add_comment( :author_name=>'fierce', :title=>'and', :text=>'ugly spam' )
    assert_equal Zena::Status[:prop], comment.status
    ZENA_ENV[:moderate_anonymous_comments] = false
    assert comment = node.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world of happiness' )
    assert_equal Zena::Status[:pub], comment.status
    node = secure(Node) { nodes(:status) }
    comments = node.comments
    assert_equal 2, node.comments.size
    assert_equal 'hello', comments[1][:title]
    assert_equal 'parrot', comments[1][:author_name]
    ZENA_ENV[:allow_anonymous_comments] = aanon
    ZENA_ENV[:moderate_anonymous_comments] = manon
  end
  
  def test_add_reply
    login(:ant)
    visitor.lang = 'en'
    node = secure(Node) { nodes(:status) }
    assert_equal 1, node.comments.size
    assert comment = node.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world', :reply_to=>comments_id(:public_says_in_en) )
    node = secure(Node) { nodes(:status) }
    comments = node.comments
    assert_equal 1, comments.size
    assert_equal 1, comments[0].replies.size
  end
  
  def test_relation_options
    login(:ant)
    node = secure(Node) { nodes(:status) }
    res = {:conditions=>["(project_id = ?) AND (kpath NOT LIKE 'NPDI%')", 11], :order=>"name ASC"}
    assert_equal res, node.relation_options({:from=>'project'}, "kpath NOT LIKE 'NPDI%'")
    res = {:conditions=>["(parent_id = ?) AND (kpath NOT LIKE 'NPDI%')", 12], :order=>"name ASC"}
    assert_equal res, node.relation_options({}, "kpath NOT LIKE 'NPDI%'")
  end
  
  def test_relation
    login(:ant)
    node = secure(Node) { nodes(:status) }
    pages = node.relation("pages", :from=>'project', :limit=>2)
    assert_equal 2, pages.size
    assert_equal 'cleanWater', pages[0][:name]
  end
end