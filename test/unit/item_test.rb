require File.dirname(__FILE__) + '/../test_helper'
#require 'document' # this is needed to load the document model.
#require 'collector'

class ItemTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :items, :versions, :doc_files, :addresses, :groups, :groups_users
  NEW_DEFAULT = {
    :name => 'hello',
    :rgroup_id => 1,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => 1,
    :project_id => 1,
  }
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
    attrs = NEW_DEFAULT
    attrs.delete(:name)
    item = secure(Item) { Item.new(attrs) }
    assert ! item.save, 'Save fails'
    assert_equal item.errors[:name], "can't be blank"
  end
  
  def test_update_no_or_bad_parent
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:wiki))}
    assert_kind_of Item, item
    assert item.save , "Save succeeds"
    item.parent_id = nil
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    item = secure(Item) { Item.find(items_id(:wiki))}
    item.parent_id = items_id(:wiki)
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    item = secure(Item) { Item.find(items_id(:wiki))}
    item.parent_id = items_id(:cleanWater)
    assert ! item.save , "Save fails"
  end
  
  def test_update_bad_parent
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:status)) }
    item[:parent_id] = items_id(:proposition)
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", item.errors[:parent_id] # parent cannot be 'Note' if self not Document
    
    item = secure(Item) { Item.find(items_id(:status)) }
    item[:parent_id] = items_id(:myDreams) # cannot write here
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", item.errors[:parent_id]
    
    item = secure(Item) { Item.find(items_id(:status)) }
    item[:parent_id] = items_id(:projects) # parent ok
    assert item.save , "Save succeeds"
  end
  
  def test_page_update_without_name
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:status)) }
    item[:name] = nil
    assert item.save, 'Save succeeds'
    assert_equal 'statusTitle', item[:name]
    item = secure(Item) { Item.find(items_id(:status)) }
    item[:name] = nil
    item.title = ""
    assert !item.save, 'Save fails'
    assert_equal item.errors[:name], "can't be blank"
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
    item = secure(Item) { Item.find(items_id(:cleanWater))}
    item.name = 'wiki'
    assert ! item.save, 'Cannot save'
    assert_equal item.errors[:name], 'has already been taken'
  end

  def test_update_same_name_other_parent
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:cleanWater))}
    item.name = 'wiki'
    item[:parent_id] = 1
    item.save
    err(item)
    assert item.save
    assert_nil item.errors[:name]
  end
  
  def test_before_destroy
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:projects)) }
    assert !item.destroy, "Cannot destroy"
    assert_equal item.errors[:base], 'contains subpages'
    item = secure(Item) { Item.find(items_id(:status)) }
    assert item.destroy, "Can destroy"
  end
  
  def test_cannot_destroy_has_private
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:lion)) }
    assert_equal 0, item.pages.size # cannot see subpages
    assert !item.destroy, "Cannot destroy"
    assert_equal item.errors[:base], 'contains subpages'
  end
  
  def test_list_children
    visitor(:ant)
    
    page = secure(Item) { Item.find(items_id(:projects)) }
    children = page.children
    assert_equal 2, children.size
    
    visitor(:tiger)
    page = secure(Item) { Item.find(items_id(:projects)) }
    children = page.children
    assert_equal 3, children.size
    assert_equal 3, page.children.size
  end
  
  def test_parent
    assert_equal items(:projects).title, secure(Item) { Item.find(items_id(:wiki))}.parent.title
  end
  
  def test_project
    assert_equal items(:zena).id, secure(Item) { Item.find(items_id(:wiki))}.project.id
  end
  
  def test_pages
    visitor(:ant)
    page = secure(Item) { Item.find(items_id(:cleanWater))}
    pages = page.pages
    assert_equal 3, pages.size
    assert_equal items(:lake)[:id], pages[0][:id]
  end
  
  def test_documents
    visitor(:ant)
    page = secure(Item) { Item.find(items_id(:cleanWater))}
    documents = page.documents
    assert_equal 1, documents.size
    assert_equal items(:water_pdf)[:id], documents[0][:id]
  end
  
  def test_documents_only
    visitor(:tiger)
    bird = secure(Item) { Item.find(items_id(:bird_jpg))}
    bird[:parent_id] = items_id(:cleanWater)
    assert bird.save
    page = secure(Item) { Item.find(items_id(:cleanWater))}
    documents = page.documents
    doconly   = page.documents_only
    images    = page.images
    assert_equal 1, doconly.size
    assert_equal items(:water_pdf)[:id], doconly[0][:id]
    assert_equal 1, images.size
    assert_equal items(:bird_jpg)[:id], images[0][:id]
  end
  
  def blah
    collectors = page.collectors
    assert_equal 0, collectors.size
    trackers = page.trackers
    assert_equal 1, trackers.size
    children = page.children
    assert_equal 5, children.size
    visitor(:tiger)
    page = secure(Item) { Item.find(items_id(:cleanWater))}
    pages = page.pages
    assert_equal 5, pages.size
  end
  
  def test_find_by_path
    visitor(:ant)
    item = Item.find_by_path(user_id,user_groups,'fr',['projects', 'wiki'])
    assert_kind_of Item, item
    assert_equal ['projects','wiki'], item.fullpath
  end
  
  def test_get_fullpath
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:lake)) }
    parent = item.parent
    assert_nil parent[:fullpath]
    assert_nil item[:fullpath]
    assert_equal ['projects', 'cleanWater', 'lake'], item.fullpath
    item.reload
    assert_equal ['projects', 'cleanWater', 'lake'], item[:fullpath].split('/')
    parent.reload
    assert_equal ['projects', 'cleanWater'], parent[:fullpath].split('/')
  end
  
  def test_list_collectors
    visitor(:tiger)
    page = secure(Item) { Item.find(items_id(:collections)) }
    collectors = page.collectors
    assert_equal 3, collectors.size
    assert_equal 3, page.pages.size
    assert_equal 3, page.children.size
  end
  
  def test_secure_find_by_path
    visitor(:tiger)
    item = Item.find_by_path(user_id, user_groups, 'fr', ['projects', 'secret'])
    assert_kind_of Item, item
    visitor(:ant)
    assert_raise(ActiveRecord::RecordNotFound) do
      item = Item.find_by_path(user_id, user_groups, 'fr', ['projects', 'secret'])
    end
  end
  
  def test_duplicate_name
    visitor(:ant)
    item = secure(Item) { Item.new(
      :parent_id=>items_id(:cleanWater),
      :inherit => 1
    ) }
    assert ! item.save
    assert item.errors[:name] , "Errors on name"
    item.name = 'lake'
    assert ! item.save
    assert item.errors[:name] , "Errors on name"
    item.name = 'wikiwikiwkwikassiejf'
    assert item.save
  end
  
  def test_camel_name
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:cleanWater)) }
    child = item.new_child( :name => 'salut j\'écris: Aujourd\'hui ' )
    assert child.save , "Save succeeds"
    assert_equal "salutJEcrisAujourdHui", child.name
  end
    
  def test_new_child
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:cleanWater)) }
    child = item.new_child( :name => 'lake' )
    assert ! child.save , "Save fails"
    assert child.errors[:name] , "Errors on name"
    
    child = item.new_child( :name => 'new_name' )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.v_status
  end
  
  def test_child_sync
    visitor(:tiger)
    # redaction containing three documents
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { Item.find(items_id(:nature)) } }
    assert_raise(ActiveRecord::RecordNotFound) { tree = secure(Item) { Item.find(items_id(:tree))   } }
    assert_raise(ActiveRecord::RecordNotFound) { forest = secure(Item) { Item.find(items_id(:tree)) } }
    
    visitor(:ant)
    # redaction containing three documents
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:red], item.v_status
    assert_equal Zena::Status[:red], tree.v_status
    assert_equal Zena::Status[:red], forest.v_status
    assert item.propose, "Propose for publication succeeds"
    
    # propositions
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:prop], item.v_status
    assert_equal Zena::Status[:prop_with], tree.v_status
    assert_equal Zena::Status[:prop_with], forest.v_status
    
    visitor(:tiger)
    # can now see all propositions
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:prop], item.v_status
    assert_equal Zena::Status[:prop_with], tree.v_status
    assert_equal Zena::Status[:prop_with], forest.v_status
    
    assert item.refuse, "Can refuse publication"
    
    visitor(:ant)
    # redactions again
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:red], item.v_status
    assert_equal Zena::Status[:red], tree.v_status
    assert_equal Zena::Status[:red], forest.v_status
    assert item.propose, "Propose for publication succeeds"
    
    visitor(:tiger)
    # sees the propositions again
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:prop], item.v_status
    assert_equal Zena::Status[:prop_with], tree.v_status
    assert_equal Zena::Status[:prop_with], forest.v_status
    
    assert item.publish, "Publication succeeds"
    
    visitor(:ant)
    # redactions again
    item = secure(Item) { Item.find(items_id(:nature)) }
    tree = secure(Item) { Item.find(items_id(:tree))   }
    forest = secure(Item) { Item.find(items_id(:tree)) }
    assert_equal Zena::Status[:pub], item.v_status
    assert_equal Zena::Status[:pub], tree.v_status
    assert_equal Zena::Status[:pub], forest.v_status
    assert item.propose, "Propose for publication succeeds"
  end
  
  def test_change_class
    visitor(:tiger)
    item = secure(Item) { Item.find(items_id(:status)) }
    item = item.change_to(Project)
    assert_kind_of Project, item
    assert item.save
    item = secure(Project) { Project.find(items_id(:status)) }
    assert_kind_of Project, item
    assert_equal 'IPP', item[:kpath]
  end
  
  def test_tags
    visitor(:lion)
    @item = secure(Item) { Item.find(items_id(:status)) }
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
end
=begin
  def test_edition
    visitor
    @lang = 'ru'
    item = secure(Item) { Item.find(1) }
    ed = item.edition
    assert_equal item.ref_lang, ed.lang
    assert_equal item.visitor_lang, 'ru'
  end
 
  def test_edition_for_lang
    zenaItem = Item.find(1)
    assert_kind_of Item, zenaItem
    zenaItem.set_visitor(1,[1], 'fr')
    ed = zenaItem.edition
    assert_kind_of Version, ed
    assert_equal versions(:zena_fr_pub).id, ed.id
    zenaItem = Item.find(1)
    zenaItem.set_visitor(1,[1], 'en')
    ed = zenaItem.edition
    assert_kind_of Version, ed
    assert_equal versions(:zena_en_pub).id, ed.id
    ed = zenaItem.edition('fr')
    assert_kind_of Version, ed
    assert_equal versions(:zena_en_pub).id, ed.id
    
    zenaItem = Item.find(1)
    zenaItem.set_visitor(1,[1], 'ru')
    ed = zenaItem.edition
    assert_kind_of Version, ed
    assert_equal versions(:zena_fr_pub).id, ed.id
    zenaItem = Item.find(1)
    ed = zenaItem.edition
    assert_kind_of Version, ed
    assert_equal versions(:zena_fr_pub).id, ed.id
    
    without_ed = Item.find(3)
    assert_kind_of Item, without_ed
    ed = without_ed.edition
    assert_nil ed
    without_ed.set_visitor(1,[1], 'ru')
    ed = without_ed.edition
    assert_nil ed
    # owner can views versions
    without_ed.set_visitor(3, [1,3], 'fr')
    ed = without_ed.edition
    assert_kind_of Version, ed
  end
end
=end
