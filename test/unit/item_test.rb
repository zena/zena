require File.dirname(__FILE__) + '/../test_helper'

class ItemTest < Test::Unit::TestCase
  include ZenaTestUnit

  NEW_DEFAULT = {
    :name => 'hello',
    :rgroup_id => 1,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => 1,
    :project_id => 1,
  }
  
  def test_find_by_path
    visitor(:ant)
    item = items(:wiki)
    assert_nil item[:fullpath]
    item = Item.find_by_path(user_id,user_groups,'fr',['projects', 'wiki'])
    assert_kind_of Item, item
    assert_equal ['projects','wiki'], item.fullpath
    item.reload
    assert_equal 'projects/wiki', item[:fullpath]
  end
  
  def test_get_fullpath
    visitor(:ant)
    item = secure(Item) { items(:lake)  }
    parent = item.parent
    assert_nil parent[:fullpath]
    assert_nil item[:fullpath]
    assert_equal ['projects', 'cleanWater', 'lake'], item.fullpath
    item.reload
    assert_equal ['projects', 'cleanWater', 'lake'], item[:fullpath].split('/')
    parent.reload
    assert_equal ['projects', 'cleanWater'], parent[:fullpath].split('/')
  end
  
  def test_get_fullpath_after_private
    Item.connection.execute "UPDATE items SET parent_id = 3 WHERE id = 12" # put 'status' page inside private 'ant' page
    item = nil
    visitor(:tiger)
    assert_nothing_raised { item = secure(Item) { items(:status) } }
    assert_kind_of Item, item
    assert_raises (ActiveRecord::RecordNotFound) { item = Item.find_by_path(user_id,user_groups,'fr',['people', 'ant'])}
    assert_nothing_raised { item = Item.find_by_path(user_id,user_groups,'fr',['people', 'ant', 'status'])}
  end
  
  def test_rootpath
    visitor(:ant)
    item = secure(Item) { items(:status) }
    assert_equal ['zena', 'projects', 'cleanWater', 'status'], item.rootpath
    item = secure(Item) { items(:zena) }
    assert_equal ['zena'], item.rootpath
  end
  
  def test_create_simplest
    visitor(:ant)
    test_page = secure(Item) { Item.create(:name=>"yoba", :parent_id=>items_id(:cleanWater), :inherit=>1 ) }
    assert ! test_page.new_record? , "Not a new record"
  end

  def test_new_bad_parent
    visitor(:tiger)
    attrs = NEW_DEFAULT
    attrs[:parent_id] = items(:proposition).id
    item = secure(Item) { Item.new(attrs) }
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", item.errors[:parent_id] # parent cannot be 'Note' if self not Document

    attrs[:parent_id] = items(:myDreams).id # cannot write here
    item = secure(Item) { Item.new(attrs) }
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", item.errors[:parent_id]

    attrs[:parent_id] = items(:cleanWater).id # parent ok
    item = secure(Item) { Item.new(attrs) }
    assert item.save , "Save succeeds"
  end
  
  def test_new_without_parent
    visitor(:tiger)
    attrs = NEW_DEFAULT
    attrs.delete(:parent_id)
    item = secure(Item) { Item.new(attrs) }
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", item.errors[:parent_id]
    # page parent ok
    assert item.new_record?
    item = secure(Item) { Item.new(attrs) }
    item.parent_id = items_id(:lake)
    assert item.save , "Save succeeds"
  end
  
  def test_page_new_without_name
    visitor(:tiger)
    item = secure(Item) { Item.new(:parent_id=>1) }
    assert ! item.save, 'Save fails'
    assert_equal "can't be blank", item.errors[:name]
  end
  
  def test_new_set_project_id
    visitor(:tiger)
    item = secure(Page) { Page.create(:parent_id=>items_id(:status), :name=>'SuperPage')}
    assert ! item.new_record?, 'Not a new record'
    assert_equal items_id(:cleanWater), item[:project_id]
  end
  
  def test_update_no_or_bad_parent
    visitor(:ant)
    item = secure(Item) { items(:wiki) }
    assert_kind_of Item, item
    assert item.save , "Save succeeds"
    item.parent_id = nil
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    item = secure(Item) { items(:wiki) }
    item.parent_id = items_id(:wiki)
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    item = secure(Item) { items(:wiki) }
    item.parent_id = items_id(:cleanWater)
    assert ! item.save , "Save fails"
  end
  
  def test_update_bad_parent
    visitor(:tiger)
    item = secure(Item) { items(:status)  }
    item[:parent_id] = items_id(:proposition)
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", item.errors[:parent_id] # parent cannot be 'Note' if self not Document
    
    item = secure(Item) { items(:status)  }
    item[:parent_id] = items_id(:myDreams) # cannot write here
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", item.errors[:parent_id]
    
    item = secure(Item) { items(:status)  }
    item[:parent_id] = items_id(:projects) # parent ok
    assert item.save , "Save succeeds"
  end
  
  def test_page_update_without_name
    visitor(:tiger)
    item = secure(Item) { items(:status)  }
    item[:name] = nil
    assert item.save, 'Save succeeds'
    assert_equal 'statusTitle', item[:name]
    item = secure(Item) { items(:status)  }
    item[:name] = nil
    item.v_title = ""
    assert !item.save, 'Save fails'
    assert_equal item.errors[:name], "can't be blank"
  end
  
  def test_update_set_project_id
    visitor(:tiger)
    item = secure(Page) { Page.find(items_id(:status))}
    assert_equal items_id(:cleanWater), item[:project_id]
    item[:parent_id]  = items_id(:zena)
    item[:project_id] = items_id(:status)
    assert item.save, 'Can save item'
    item.reload
    assert_equal items_id(:zena), item[:project_id]
  end
  
  def test_create_same_name
    visitor(:tiger)
    item = secure(Item) { Item.create(:parent_id=>items(:wiki)[:parent_id], :name=>'wiki')}
    assert item.new_record?
    assert_equal item.errors[:name], 'has already been taken'
  end
  
  def test_create_same_name_other_parent
    visitor(:tiger)
    item = secure(Item) { Item.create(:parent_id=>1, :name=>'wiki')}
    assert ! item.new_record?, 'Not a new record'
    assert_nil item.errors[:name]
  end

  def test_update_same_name
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater) }
    item.name = 'wiki'
    assert ! item.save, 'Cannot save'
    assert_equal item.errors[:name], 'has already been taken'
  end

  def test_update_same_name_other_parent
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater) }
    item.name = 'wiki'
    item[:parent_id] = 1
    item.save
    err(item)
    assert item.save
    assert_nil item.errors[:name]
  end
  
  def test_before_destroy
    visitor(:tiger)
    item = secure(Item) { items(:projects)  }
    assert !item.destroy, "Cannot destroy"
    assert_equal item.errors[:base], 'contains subpages'
    item = secure(Item) { items(:status)  }
    assert item.destroy, "Can destroy"
  end
  
  def test_cannot_destroy_has_private
    visitor(:tiger)
    item = secure(Item) { items(:lion)  }
    assert_equal 0, item.pages.size # cannot see subpages
    assert !item.destroy, "Cannot destroy"
    assert_equal item.errors[:base], 'contains subpages'
  end
  
  def test_list_children
    visitor(:ant)
    
    page = secure(Item) { items(:projects)  }
    children = page.children
    assert_equal 2, children.size
    
    visitor(:tiger)
    page = secure(Item) { items(:projects)  }
    children = page.children
    assert_equal 3, children.size
    assert_equal 3, page.children.size
  end
  
  def test_parent
    assert_equal items(:projects).v_title, secure(Item) { items(:wiki) }.parent.v_title
  end
  
  def test_project
    assert_equal items(:zena).id, secure(Item) { items(:wiki) }.project.id
  end
  
  def test_pages
    visitor(:ant)
    page = secure(Item) { items(:cleanWater) }
    pages = page.pages
    assert_equal 3, pages.size
    assert_equal items(:lake)[:id], pages[0][:id]
  end
  
  def test_documents
    visitor(:ant)
    page = secure(Item) { items(:cleanWater) }
    documents = page.documents
    assert_equal 1, documents.size
    assert_equal items(:water_pdf)[:id], documents[0][:id]
  end
  
  def test_documents_images_only
    visitor(:tiger)
    bird = secure(Item) { items(:bird_jpg) }
    bird[:parent_id] = items_id(:cleanWater)
    assert bird.save
    page = secure(Item) { items(:cleanWater) }
    doconly   = page.documents_only
    images    = page.images
    assert_equal 1, doconly.size
    assert_equal items(:water_pdf)[:id], doconly[0][:id]
    assert_equal 1, images.size
    assert_equal items(:bird_jpg)[:id], images[0][:id]
  end
  
  def test_notes
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater) }
    notes = item.notes
    assert_equal 1, notes.size
    assert_equal 'opening', notes[0][:name]
  end
  
  def test_trackers
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater) }
    trackers = item.trackers
    assert_equal 1, trackers.size
    assert_equal 'track', trackers[0][:name]
  end
  
  def test_new_child
    visitor(:ant)
    item = secure(Item) { items(:cleanWater)  }
    child = item.new_child( :name => 'lake' )
    assert ! child.save , "Save fails"
    assert child.errors[:name] , "Errors on name"
  
    child = item.new_child( :name => 'new_name' )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.v_status
    assert_equal child[:user_id], users_id(:ant)
    assert_equal item[:pgroup_id], child[:pgroup_id]
    assert_equal item[:rgroup_id], child[:rgroup_id]
    assert_equal item[:wgroup_id], child[:wgroup_id]
    assert_equal item[:project_id], child[:project_id]
    assert_equal 1, child[:inherit]
    assert_equal item[:id], child[:parent_id]
  end
  
  def test_secure_find_by_path
    visitor(:tiger)
    item = Item.find_by_path(user_id, user_groups, 'fr', ['projects', 'secret'])
    assert_kind_of Item, item
    visitor(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { item = Item.find_by_path(user_id, user_groups, 'fr', ['projects', 'secret']) }
  end
  
  def test_author
    item = items(:status)
    assert_equal item.user, item.author
    assert_equal 'ant', item.author.login
  end
  
  def test_ext
    item = items(:status)
    item[:name] = 'bob. and bob.jpg'
    assert_equal 'jpg', item.ext
    item[:name] = 'no ext'
    assert_equal '', item.ext
    item[:name] = ''
    assert_equal '', item.ext
    item[:name] = nil
    assert_equal '', item.ext
  end
  
  def test_set_name
    item = items(:wiki)
    item.name = " J'aime l'aïl en août ! "
    assert_equal 'JAimeLAilEnAout', item.name
    assert_equal 'JAimeLAilEnAout', item[:name]    
  end
 
  def test_change_to_page_to_project
    visitor(:tiger)
    item = secure(Item) { items(:people)  }
    id, parent_id, project_id = item[:id], item[:parent_id], item[:project_id]
    vers_count = Version.find(:all).size
    vers_id = item.v_id
    item = item.change_to(Project)
    assert_kind_of Project, item
    item = secure(Project) { Project.find(items_id(:people)) }
    assert_kind_of Project, item
    assert_equal 'IPP', item[:kpath]
    assert_equal id, item[:id]
    assert_equal parent_id, item[:parent_id]
    assert_equal item[:id], item[:project_id]
    assert_equal vers_count, Version.find(:all).size
    assert_equal vers_id, item.v_id
    assert_equal item[:id], items(:ant)[:project_id] # children inherit new project_id
    assert_equal item[:id], items(:myLife)[:project_id]
  end
  
  def test_change_project_to_page
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater)  }
    id, parent_id = item[:id], item[:parent_id]
    vers_count = Version.find(:all).size
    vers_id = item.v_id
    item = item.change_to(Page)
    assert_kind_of Page, item
    item = secure(Page) { Page.find(items_id(:cleanWater)) }
    assert_kind_of Page, item
    assert_equal 'IP', item[:kpath]
    assert_equal id, item[:id]
    assert_equal parent_id,  item[:parent_id]
    assert_equal items_id(:zena), item[:project_id]
    assert_equal vers_count, Version.find(:all).size
    assert_equal vers_id, item.v_id
    assert_equal items_id(:zena), items(:status)[:project_id] # children inherit new project_id
    assert_equal items_id(:zena), items(:lake)[:project_id]
  end
  
  def test_cannot_change_root
    visitor(:tiger)
    item = secure(Item) { Item.find(ZENA_ENV[:root_id]) }
    item = item.change_to(Page)
    assert_nil item
    item = secure(Item) { Item.find(ZENA_ENV[:root_id]) }
    assert_kind_of Project, item
  end
  
  def test_sync_project
    visitor(:tiger)
    item = secure(Item) { items(:projects) }
    item.send(:sync_project, 99)
    assert_equal items_id(:cleanWater), items(:cleanWater)[:project_id]
    item = secure(Item) { items(:people) }
    item.send(:sync_project, 99)
    assert_equal 99, items(:ant)[:project_id]
    assert_equal 99, items(:myLife)[:project_id]
  end
  
  def test_spread_project_id
    visitor(:tiger)
    item = secure(Item) { items(:people) }
    item.parent_id =   items_id(:status) # in project cleanWater
    assert item.save
    assert_equal items_id(:cleanWater), item[:project_id]
    assert_equal items_id(:cleanWater), items(:ant)[:project_id]
    assert_equal items_id(:cleanWater), items(:myLife)[:project_id]
  end
  
  def test_after_remove
    Version.connection.execute "UPDATE versions SET user_id=4 WHERE item_id IN (19,20,21)"
    Item.connection.execute "UPDATE items SET user_id=4 WHERE id IN (19,20,21)"
    visitor(:tiger)
    wiki = secure(Item) { items(:wiki) }
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:pub], wiki.v_status
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], flower.v_status
    assert wiki.remove, 'Can remove publication'
    assert_equal 10, wiki.v_status
    assert_equal 10, wiki.max_status
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal 10, bird.v_status
    assert_equal 10, flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_propose
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE item_id IN (19,20,21)"
    Item.connection.execute "UPDATE items SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    visitor(:tiger)
    wiki = secure(Item) { items(:wiki) }
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:red], wiki.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], flower.v_status
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_refuse
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE item_id IN (19,20,21)"
    Item.connection.execute "UPDATE items SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    visitor(:tiger)
    wiki = secure(Item) { items(:wiki) }
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.refuse, 'Can refuse'
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.max_status
    assert_equal Zena::Status[:red], flower.v_status
  end
  
  def test_after_publish
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=4 WHERE item_id IN (19,20,21)"
    Item.connection.execute "UPDATE items SET max_status = #{Zena::Status[:red]}, user_id=4 WHERE id IN (19,20,21)"
    visitor(:tiger)
    wiki = secure(Item) { items(:wiki) }
    assert wiki.publish, 'Can publish'
    assert_equal Zena::Status[:pub], wiki.v_status
    bird = secure(Item) { items(:bird_jpg) }
    flower = secure(Item) { items(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_all_children
    visitor(:tiger)
    people_id = items_id(:people)
    ant_id = items_id(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { secure(Item) { Item.find(ant_id) }  }
    items  = secure(Item) { Item.find(people_id).send(:all_children) }
    people = secure(Item) { Item.find(people_id)}
    assert_equal 3, items.size
    assert_equal 2, people.children.size
    assert_raise(NoMethodError) { people.all_children }
  end
  
  def test_camelize
    item = items(:wiki)
    assert_equal "salutJEcrisAujourdHui", item.send(:camelize,"salut j'écris: Aujourd'hui ")
    assert_equal "aBabMol", item.send(:camelize," à,--/ bab mol")
    assert_equal "07.11.2006Mardi", item.send(:camelize,"07.11.2006-mardi")
  end
  
  def test_tags
    visitor(:lion)
    @item = secure(Item) { items(:status)  }
    assert_nothing_raised { @item.tags }
    assert_equal [], @item.tags
    @item.tag_ids = [items_id(:art),items_id(:news)]
    assert @item.save
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @item.tag_ids = [items_id(:art)]
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end
  
  def test_tags_callbacks
    assert Item.read_inheritable_attribute(:after_save).include?(:save_tags)
    assert Page.read_inheritable_attribute(:after_save).include?(:save_tags)
  end
  
  def test_after_all_cache_sweep
    visitor(:lion)
    i = 1
    assert_equal "content 1", Cache.with(user_id, user_groups, 'IP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(user_id, user_groups, 'IN', 'notes')  { "content #{i}" }
    i = 2
    assert_equal "content 1", Cache.with(user_id, user_groups, 'IP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(user_id, user_groups, 'IN', 'notes')  { "content #{i}" }
    
    # do something on a document
    item = secure(Item) { items(:water_pdf) }
    assert_equal 'IPD', item.class.kpath
    assert item.update_attributes(:v_title=>'new title'), "Can change attributes"
    # sweep only kpath IPD
    i = 3
    assert_equal "content 3", Cache.with(user_id, user_groups, 'IP', 'pages')  { "content #{i}" }
    assert_equal "content 1", Cache.with(user_id, user_groups, 'IN', 'notes')  { "content #{i}" }
    
    # do something on a note
    item = secure(Item) { items(:proposition) }
    assert_equal 'IN', item.class.kpath
    assert item.update_attributes(:name=>'popo'), "Can change attributes"
    # sweep only kpath IPD
    i = 4
    assert_equal "content 3", Cache.with(user_id, user_groups, 'IP', 'pages')  { "content #{i}" }
    assert_equal "content 4", Cache.with(user_id, user_groups, 'IN', 'notes')  { "content #{i}" }
  end
  
  def test_empty_comments
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert_equal [], item.comments
  end
  
  def test_discussion_lang
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_equal Zena::Status[:pub], item.v_status
    discussion = item.discussion
    assert_kind_of Discussion, discussion
    assert_equal discussions_id(:outside_discussion_on_status_en), discussion[:id]
    visitor(:ant)
    item = secure(Item) { items(:status) }
    discussion = item.discussion
    assert discussion.new_record?, "New discussion"
    assert_equal 'fr', discussion.lang
    assert discussion.open?
    assert !discussion.inside?
  end
  
  def test_closed_discussion
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    discussion = item.discussion
    discussion.update_attributes(:open=>false)
    item = secure(Item) { items(:status) }
    assert_equal discussions_id(:outside_discussion_on_status_en), item.discussion[:id]
    visitor(:ant)
    item = secure(Item) { items(:status) }
    assert_nil item.discussion
    item.update_attributes( :v_title=>'test' )
    discussion = item.discussion
    assert_kind_of Discussion, discussion
    assert discussion.inside?
  end
  
  def test_inside_discussion
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    item.update_attributes( :v_title=>'new status' )
    assert_equal Zena::Status[:red], item.v_status
    discussion = item.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end
  
  def test_comments
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    comments = item.comments
    assert_kind_of Comment, comments[0]
    assert_equal 'Nice site', comments[0][:title]
  end
  
  def test_comments_on_nil
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater) }
    assert_nil item.discussion # no open discussion here
    assert_equal [], item.comments
  end
  
  def test_add_comment
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_equal 1, item.comments.size
    assert comment = item.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world' )
    item = secure(Item) { items(:status) }
    comments = item.comments
    assert_equal 2, item.comments.size
    assert_equal 'hello', comments[1][:title]
    assert_equal nil, comments[1][:author_name]
  end
  
  def test_public_add_comment
    item = secure(Item) { items(:status) }
    assert_equal 1, item.comments.size
    assert comment = item.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world' )
    item = secure(Item) { items(:status) }
    comments = item.comments
    assert_equal 2, item.comments.size
    assert_equal 'hello', comments[1][:title]
    assert_equal 'parrot', comments[1][:author_name]
  end
  
  def test_add_reply
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_equal 1, item.comments.size
    assert comment = item.add_comment( :author_name=>'parrot', :title=>'hello', :text=>'world', :reply_to=>comments_id(:public_says_in_en) )
    item = secure(Item) { items(:status) }
    comments = item.comments
    assert_equal 1, comments.size
    assert_equal 1, comments[0].replies.size
  end
end