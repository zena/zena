require File.dirname(__FILE__) + '/../test_helper'
class PagerDummy < Item
  def self.ksel
    self == PagerDummy ? 'U' : super
  end
end
class SubPagerDummy < PagerDummy
end
class SecureReadTest < Test::Unit::TestCase

  include ZenaTestUnit
  
  def test_fixture_by_id
    assert_equal 1, items_id(:zena)
  end
  def test_kpath
    assert_equal Item.kpath, 'I'
    assert_equal Page.kpath, 'IP'
    assert_equal PagerDummy.ksel, 'U'
    assert_equal PagerDummy.kpath, 'IU'
    assert_equal SubPagerDummy.kpath, 'IUS'
  end
  def test_callbacks
    assert Item.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert Page.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert Item.read_inheritable_attribute(:validate_on_create).include?(:item_on_create)
    assert Item.read_inheritable_attribute(:validate_on_update).include?(:item_on_update)
    assert Page.read_inheritable_attribute(:validate_on_create).include?(:item_on_create)
    assert Page.read_inheritable_attribute(:validate_on_update).include?(:item_on_update)
  end
  # SECURE FIND TESTS  ===== TODO CORRECT THESE TEST FROM CHANGES TO RULES ========
  # [user]          Item owner. Can *read*, *write* and (*manage*: if item not published yet or item is private).
  def test_can_rwm_own_private_item
    visitor(:lion)
    item = secure(Item) { items(:myDreams)  }
    assert_kind_of Item, item
    assert_equal 'myDreams', item.name
    assert item.can_read?, "Can read"
    assert item.can_write? , "Can write"
    assert item.private? , "Item is private"
    assert ! item.can_publish? , "Cannot publish"
    assert item.can_manage? , "Can manage"
  end
  def test_cannot_view_others_private_items
    visitor(:lion)
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { items(:myLife)  }}
  end
  def test_owner_but_not_in_rgroup
    visitor(:ant)
    item = secure(Item) { items(:proposition)  }
    assert_kind_of Item, item
    assert item.can_read? , "Can read"
    assert item.can_write? , "Can write"
    assert ! item.can_publish? , "Can publish"
  end
  def test_cannot_rwpm_if_not_owner_and_not_in_any_group
    visitor(:ant)
    # not in any group and not owner
    item = items(:secret)
    item.set_visitor(user_id, user_groups, lang)
    assert ! item.can_read? , "Can read"
    assert ! item.can_write? , "Can write"
    assert ! item.can_publish? , "Can publish"
    assert ! item.can_manage? , "Can manage"
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { Item.find(item.id) }}
  end
  
  def test_rgroup_can_read_if_published
    # visitor = public
    # not published, cannot read
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { items(:crocodiles)  }}
    # published: can read
    item = secure(Item) { items(:lake)  }
    assert_kind_of Item, item
  end
  # write group can only write
  def test_write_group_can_w
    visitor(:tiger)
    item = ""
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { items(:strange)  } }
    assert_nothing_raised { item = secure_write(Item) { items(:strange)  } }
    assert ! item.can_read? , "Cannot read"
    assert item.can_write? , "Can write"
  end
  # pgroup can only publish
  def test_publish_group_can_rwp
    visitor(:ant)
    item = ""
    ant = users(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { items(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure_write(Item) { items(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure_drive(Item) { items(:strange)  } }
    
    visitor(:lion)
    lion_item = ""
    assert_nothing_raised { lion_item = secure(Item) { items(:strange)  } }
    assert lion_item.can_read? , "Owner can read"
    assert lion_item.propose , "Can propose"
    
    visitor(:ant)
    # now item is 'prop', pgroup can see it
    assert_nothing_raised { item = secure(Item) { items(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure_write(Item) { items(:strange)  } }
    assert_nothing_raised { item = secure_drive(Item) { items(:strange)  } }
    assert ! ant.group_ids.include?(item.rgroup_id) , "Visitor is not in rgroup"
    assert ! ant.group_ids.include?(item.wgroup_id) , "Visitor is not in wgroup"
    assert ! (ant.id == item.user_id) , "Visitor is not the owner"
    assert ant.group_ids.include?(item.pgroup_id) , "Visitor is in pgroup"
    assert item.can_publish? , "Can publish"
    assert item.can_read? , "Can read as item is 'proposed'"
    assert ! item.can_write? , "Cannot write"
    assert ! item.can_manage? , "Cannot manage"
  end
  
  def test_public_not_in_rgroup_cannot_rwp
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { items(:secret)  } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure_write(Item) { items(:secret)  } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure_drive(Item) { items(:secret)  } }
    item = items(:secret) .set_visitor(1,[1],'en')
    assert ! item.can_read? , "Cannot read"
    assert ! item.can_write? , "Cannot write"
    assert ! item.can_publish? , "Cannot publish"
  end
  def test_pgroup_can_read_unplished_items
    # create an unpublished item
    visitor(:lion)
    item = secure(Item) { items(:strange)  }
    item = secure(Item) { item.clone }
    item[:publish_from] = nil
    item[:name] = "new_rec"
    assert item.new_record?
    assert item.save
    
    visitor(:ant)
    # item is 'red', cannot see it
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Page) { Page.find_by_name("new_rec") } }
    
    visitor(:lion)
    assert item.propose , "Can propose item for publication."
    
    visitor(:ant)
    # item can now be seen
    assert_nothing_raised { item = secure(Page) { Page.find_by_name("new_rec") } }
    assert_nil item[:publish_from] , "Not published yet"
  end
end

class SecureCreateTest < Test::Unit::TestCase

  include ZenaTestUnit
  def item_defaults
    {
    :name       => 'hello',
    :parent_id  => 1
    }
  end
  
  # VALIDATE ON CREATE TESTS
  def test_unsecure_new_fails
    visitor(:ant)
    # unsecure creation :
    test_page = Item.new(item_defaults)
    assert ! test_page.save , "Save fails"
    assert_equal "record not secured", test_page.errors[:base]
  end
  def test_secure_new_succeeds
    visitor(:ant)
    test_page = secure(Item) { Item.new(:name=>"yoba", :parent_id=>1) }
    assert test_page.save , "Save succeeds"
  end
  def test_unsecure_create_fails
    visitor(:ant)
    p = Item.create(item_defaults)
    assert p.new_record? , "New record"
    assert_equal "record not secured", p.errors[:base]
  end
  def test_secure_create_succeeds
    visitor(:ant)
    p = secure(Item) { Item.create(item_defaults) }
    assert ! p.new_record? , "Not a new record"
    assert p.id , "Has an id"
  end
  
  # 0. set item.user_id = visitor_id
  def test_owner_is_visitor_on_new
    visitor(:ant)
    test_page = secure(Item) { Item.new(item_defaults) }
    test_page[:user_id] = 99 # try to fool
    assert test_page.save , "Save succeeds"
    assert_equal users_id(:ant), test_page.user_id
  end
  def test_owner_is_visitor_on_create
    visitor(:ant)
    attrs = item_defaults
    attrs[:user_id] = 99
    page = secure(Item) { Item.create(attrs) }
    assert_equal users_id(:ant), page.user_id
  end
  def test_status
    visitor(:tiger)
    item = secure(Item) { Item.new(item_defaults) }
    assert_equal Zena::Status[:red], item.max_status, "New item max_status is 'red'"
    assert_equal Zena::Status[:red], item.v_status, "Version status is 'red'"
    
    assert item.save, "Item saved"
    assert_equal Zena::Status[:red], item.max_status, "Max_status did not change"
    assert item.propose, "Can propose item"
    assert_equal Zena::Status[:prop], item.max_status, "Item#{item[:id]} max_status is now 'prop'"
    assert item.publish, "Can publish item"
    assert_equal Zena::Status[:pub], item.max_status, "item max_status in now 'pub'"
    id = item.id
    visitor(:ant)
    assert_nothing_raised { item = secure(Item) { Item.find(id) } }
    assert item.update_attributes(:v_summary=>'hello my friends'), "Can create a new edition"
    assert_equal Zena::Status[:pub], item.max_status, "Item max_status did not change"
    assert item.propose, "Can propose edition"
    assert_equal Zena::Status[:pub], item.max_status, "Item max_status did not change"
    # TODO continue test when 'remove, replace, rollback, ...' are implemented
  end
  # 2. valid reference (in which the visitor has write access and ref<>self !)
  def test_invalid_reference_cannot_write_in_new
    visitor(:ant)
    attrs = item_defaults
    
    # ant cannot write into secret
    attrs[:parent_id] = items_id(:secret)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", z.errors[:parent_id]
  end
  def test_invalid_reference_not_correct_class
    visitor(:ant)
    attrs = item_defaults
    
    # lake is not a Project (Notes use Projects as references)
    attrs[:parent_id] = items_id(:lake)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", z.errors[:parent_id]
  end
  def test_no_reference
    # root items do not have a parent_id !!
    # reference = self
    visitor(:lion)
    z = secure(Item) { items(:zena)  }
    assert_nil z[:parent_id]
    z[:pgroup_id] = 1
    assert z.save, "Can change root group"
  end
  
  def test_circular_reference
    visitor(:tiger)
    item = secure(Item) { items(:projects)  }
    item[:parent_id] = items_id(:status)
    assert ! item.save, 'Save fails'
    assert_equal item.errors[:parent_id], 'circular reference'
  end
  
  def test_existing_circular_reference
    visitor(:tiger)
    Item.connection.execute "UPDATE items SET parent_id = #{items_id(:cleanWater)} WHERE id=#{items_id(:projects)}"
    item = secure(Item) { items(:status)  }
    item[:parent_id] = items_id(:projects)
    assert ! item.save, 'Save fails'
    assert_equal item.errors[:parent_id], 'circular reference'
  end
  
  def test_valid_without_circular
    visitor(:tiger)
    item = secure(Item) { items(:status)  }
    item[:parent_id] = items_id(:zena)
    assert item.save, 'Save succeeds'
  end
  
  def test_set_reference_for_root
    visitor(:tiger)
    item = secure(Item) { items(:zena)  }
    item.name = 'bob'
    assert item.save
    item[:parent_id] = items_id(:status)
    assert ! item.save, 'Save fails'
    assert_equal 'parent must be empty for root', item.errors[:parent_id]
  end
  
  def test_valid_reference
    visitor(:ant)
    attrs = item_defaults
    
    # ok
    attrs[:parent_id] = items_id(:cleanWater)
    z = secure(Note) { Note.create(attrs) }
    assert ! z.new_record? , "Not a new record"
    assert z.errors.empty? , "No errors"
  end
  
  # 3. validate +publish_group+ value (same as parent or ref.can_publish? and valid)
  def test_valid_publish_group_cannot_change_if_not_ref_can_publish
    visitor(:ant)
    attrs = item_defaults
    
    # can create item in cleanWater
    cw = items(:cleanWater)
    attrs[:parent_id] = cw[:id]
    z = secure(Note) { Note.create(attrs) }
    assert z.errors.empty? , "No errors"
    # cannot publish in ref 'cleanWater'
    attrs[:pgroup_id] = 1
    z = secure(Note) { Note.create(attrs) }
    assert z.errors[:pgroup_id] , "Errors on pgroup_id"
    assert_equal "you cannot change this", z.errors[:pgroup_id]
  end
  def test_invalid_publish_group_visitor_not_in_group_set
    visitor(:ant)
    attrs = item_defaults
    
    # can publish in ref 'wiki', but is not in group managers
    attrs[:parent_id] = items_id(:wiki)
    attrs[:pgroup_id] = groups_id(:managers)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:pgroup_id] , "Errors on pgroup_id"
    assert_equal "unknown group", z.errors[:pgroup_id]
  end
  def test_valid_publish_group
    visitor(:ant)
    attrs = item_defaults
    wiki = items(:wiki)
    attrs[:parent_id] = wiki[:id]
    # ant is in 'workers', all should be ok
    attrs[:pgroup_id] = groups_id(:workers)
    z = secure(Note) { Note.create(attrs) }
    
    assert ! z.new_record? , "Not a new record"
    assert z.errors.empty? , "No errors"
    assert_equal wiki[:rgroup_id], z[:rgroup_id] , "Same rgroup as parent"
    assert_equal wiki[:wgroup_id], z[:wgroup_id] , "Same wgroup as parent"
    assert_equal groups_id(:workers), z[:pgroup_id] , "New pgroup set"
  end
  
  # 4. validate +rw groups+ :
  #     a. if can_publish? : valid groups
  def test_can_pub_bad_rgroup
    visitor(:tiger)
    attrs = item_defaults

    p = secure(Item) { Item.find(attrs[:parent_id])}
    assert p.can_publish? , "Can publish"
    
    # bad rgroup
    attrs[:rgroup_id] = 99999
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:rgroup_id] , "Error on rgroup_id"
    assert_equal "unknown group", z.errors[:rgroup_id]
  end
  def test_can_pub_bad_rgroup_visitor_not_in_group
    visitor(:tiger)
    attrs = item_defaults
    attrs[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:rgroup_id], "Error on rgroup_id"
    assert_equal "unknown group", z.errors[:rgroup_id]
  end
  def test_can_pub_bad_wgroup
    visitor(:tiger)
    attrs = item_defaults
    # bad wgroup
    attrs[:wgroup_id] = 99999
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", z.errors[:wgroup_id]
  end
  def test_can_pub_bad_wgroup_visitor_not_in_group
    visitor(:tiger)
    attrs = item_defaults
    
    attrs[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", z.errors[:wgroup_id]
  end
  def test_can_pub_rwgroups_ok
    visitor(:tiger)
    attrs = item_defaults
    zena = items(:zena)
    attrs[:parent_id] = zena[:id]
    # all ok
    attrs[:wgroup_id] = 4
    z = secure(Note) { Note.create(attrs) }
    err z
    assert ! z.new_record?, "Not a new record"
    assert z.errors.empty? , "Errors empty"
    assert_equal zena[:rgroup_id], z[:rgroup_id] , "Same rgroup as parent"
    assert_equal 4, z[:wgroup_id] , "New wgroup set"
    assert_equal zena[:pgroup_id], z[:pgroup_id] , "Same pgroup_id as parent"
  end
  
  #     b. else (can_manage as item is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
  def test_can_man_cannot_change_pgroup
    visitor(:ant)
    attrs = item_defaults

    attrs[:parent_id] = items_id(:zena) # ant can write but not publish here
    p = secure(Project) { Project.find(attrs[:parent_id])}
    assert ! p.can_publish? , "Cannot publish in reference"
    assert p.can_write? , "Can write in reference"
    
    # cannot change pgroup
    attrs[:pgroup_id] = 1
    assert (attrs[:pgroup_id] != p.pgroup_id) , "Publish group is different from reference"
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:pgroup_id] , "Errors on pgroup_id"
    assert_equal "you cannot change this", z.errors[:pgroup_id]
  end
  def test_can_man_cannot_change_rw_groups
    visitor(:ant)
    attrs = item_defaults

    attrs[:parent_id] = items_id(:zena) # ant can write but not publish here
    p = secure(Project) { Project.find(attrs[:parent_id])}
    
    # change groups
    attrs[:rgroup_id] = 98984984 # anything
    attrs[:wgroup_id] = 98984984 # anything
    attrs[:pgroup_id] = p.pgroup_id # same as reference
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:rgroup_id] , "Errors on rgroup_id"
    assert z.errors[:wgroup_id] , "Errors on wgroup_id"
    assert_equal "you cannot change this", z.errors[:rgroup_id]
    assert_equal "you cannot change this", z.errors[:wgroup_id]
  end
  def test_can_man_can_make_private
    visitor(:ant)
    attrs = item_defaults

    attrs[:parent_id] = items_id(:zena) # ant can write but not publish here
    p = secure(Project) { Project.find(attrs[:parent_id])}
    
    # make private
    attrs[:inherit  ] = -1 # make private
    attrs[:rgroup_id] = 98984984 # anything
    attrs[:wgroup_id] = 98984984 # anything
    attrs[:pgroup_id] = 98984984 # anything
    z = secure(Note) { Note.create(attrs) }
    assert ! z.new_record? , "Not a new record"
    assert_equal 0, z.rgroup_id , "Read group is 0"
    assert_equal 0, z.wgroup_id , "Write group is 0"
    assert_equal 0, z.pgroup_id , "Publish group is 0"
    assert_equal -1, z.inherit , "Inherit mode is -1"
  end
  def test_can_man_can_inherit_rwp_groups
    visitor(:ant)
    attrs = item_defaults

    attrs[:parent_id] = items_id(:zena) # ant can write but not publish here
    p = secure(Project) { Project.find(attrs[:parent_id])}
    # inherit
    attrs[:inherit  ] = 1
    attrs[:rgroup_id] = 98449484 # anything
    attrs[:wgroup_id] = nil # anything
    attrs[:pgroup_id] = 98984984 # anything
    z = secure(Note) { Note.create(attrs) }
    assert ! z.new_record? , "Not a new record"
    assert_equal p.rgroup_id, z.rgroup_id ,    "Read group is same as reference"
    assert_equal p.wgroup_id, z.wgroup_id ,   "Write group is same as reference"
    assert_equal p.pgroup_id, z.pgroup_id , "Publish group is same as reference"
  end
  # 5. validate the rest
  # testing is done in page_test or item_test
end

class SecureUpdateTest < Test::Unit::TestCase

  include ZenaTestUnit
  
  # VALIDATE ON UPDATE TESTS
  # 1. if pgroup changed from old, make sure user could do this and new group is valid
  def test_pgroup_changed_cannot_publish
    # cannot publish
    visitor(:ant)
    item = secure(Item) { items(:lake) }
    assert_kind_of Item, item
    assert ! item.can_publish? , "Cannot publish"
    item.pgroup_id = 1
    assert ! item.save , "Save fails"
    assert item.errors[:base] , "Errors on base"
    assert "you do not have the rights to do this", item.errors[:base]
  end
  def test_inherit_changed_cannot_publish
    # cannot publish
    visitor(:ant)
    parent = items(:cleanWater)
    item = secure(Page) { Page.create(:parent_id=>parent[:id], :name=>'thing')}
    assert_kind_of Item, item
    assert ! item.new_record?  , "Not a new record"
    assert ! item.can_publish? , "Cannot publish"
    assert item.can_manage? , "Can manage"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    item.inherit = 0
    assert ! item.save , "Save fails"
    assert item.errors[:inherit] , "Errors on inherit"
    assert "invalid value", item.errors[:inherit]
  end
  def test_pgroup_changed_bad_pgroup_visitor_not_in_group
    # bad pgroup
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert_kind_of Item, item
    assert item.can_publish? , "Can publish"
    item[:inherit  ] = 0
    item[:pgroup_id] = 2
    assert ! item.save , "Save fails"
    assert item.errors[:pgroup_id] , "Errors on pgroup_id"
    assert "unknown group", item.errors[:pgroup_id]
  end
  def test_pgroup_changed_ok
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert_kind_of Item, item
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    item[:inherit  ] = 0
    item[:pgroup_id] = 1
    assert item.save , "Save succeeds"
    assert_equal 0, item.inherit , "Inherit mode is 0"
  end
  def test_pgroup_cannot_nil_unless_owner
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert_equal users_id(:ant), item[:user_id]
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    assert_equal 4, item.pgroup_id
    item[:inherit  ] = 0
    item[:pgroup_id] = nil
    assert !item.save , "Save fails"
    assert item.errors[:inherit]
  end
  def test_pgroup_can_nil_if_owner
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:people) }
    assert_equal users_id(:tiger), item[:user_id]
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    assert_equal 4, item.pgroup_id
    item[:inherit  ] = 0
    item[:pgroup_id] = nil
    assert item.save , "Save succeeds"
    assert item.private?, "Item is now private"
  end
  def test_rgroup_change_rgroup_with_nil_ok
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    assert_equal 1, item.rgroup_id
    item[:inherit  ] = 0
    item[:rgroup_id] = nil
    assert item.save , "Save succeeds"
    assert_equal 0, item.inherit , "Inherit mode is 0"
    assert_equal 0, item.rgroup_id
    assert !item.private?, "Not private"
  end
  def test_rgroup_change_rgroup_with_0_ok
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    assert_equal 1, item.rgroup_id
    item[:inherit  ] = 0
    item[:rgroup_id] = 0
    assert item.save , "Save succeeds"
    assert_equal 0, item.inherit , "Inherit mode is 0"
    assert_equal 0, item.rgroup_id
  end
  def test_rgroup_change_to_private_with_empty_ok
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    assert_kind_of Item, item
    assert item.can_publish? , "Can publish"
    assert_equal 1, item.inherit , "Inherit mode is 1"
    assert_equal 1, item.rgroup_id
    item[:inherit  ] = 0
    item[:rgroup_id] = ''
    assert item.save , "Save succeeds"
    assert_equal 0, item.inherit , "Inherit mode is 0"
    assert_equal 0, item.rgroup_id
  end
  def test_group_changed_children_too
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater)  }
    item[:inherit  ] = 0
    item[:rgroup_id] = 3
    assert item.save , "Save succeeds"
    assert_equal 3, item[:rgroup_id], "Read group changed"
    assert_equal 3, items(:status).rgroup_id, "Child read group changed"
    assert_equal 3, items(:water_pdf).rgroup_id, "Child read group changed"
    assert_equal 3, items(:lake_jpg).rgroup_id, "Grandchild read group changed"
    assert_equal 4, items(:bananas).rgroup_id, "Not inherited child: rgroup not changed"
  end
  
  
  def test_template_changed_children_too
    visitor(:tiger)
    item = secure(Item) { items(:cleanWater)  }
    item[:inherit  ] = 0
    item[:template] = 'wiki'
    assert item.save , "Save succeeds"
    assert_equal 'wiki', item[:template], "Template changed"
    assert_equal 'wiki', items(:status    ).template, "Child template group changed"
    assert_equal 'wiki', items(:water_pdf ).template, "Child template group changed"
    assert_equal 'wiki', items(:lake_jpg  ).template, "Grandchild template group changed"
    assert_equal 'default', items(:bananas).template, "Not inherited child: template not changed"
  end
  
  # 2. if owner changed from old, make sure only a user in 'admin' can do this
  def test_owner_changed_visitor_not_admin
    # not in 'admin' group
    visitor(:tiger)
    item = secure(Item) { items(:bananas) }
    assert_kind_of Item, item
    assert_equal users_id(:lion), item.user_id
    item.user_id = users_id(:tiger)
    assert ! item.save , "Save fails"
    assert item.errors[:user_id] , "Errors on user_id"
    assert_equal "you cannot change this", item.errors[:user_id]
  end
  def test_owner_changed_bad_user
    # cannot write in new contact
    visitor(:lion)
    item = secure(Item) { items(:bananas) }
    assert_kind_of Item, item
    assert_equal users_id(:lion), item.user_id
    item.user_id = 99
    assert ! item.save , "Save fails"
    assert item.errors[:user_id] , "Errors on user_id"
    assert_equal "unknown user", item.errors[:user_id]
  end
  def test_owner_changed_ok
    visitor(:lion)
    item = secure(Item) { items(:bananas) }
    item.user_id = users_id(:tiger)
    assert item.save , "Save succeeds"
    item.reload
    assert_equal users_id(:tiger), item.user_id
  end
  
  # 3. error if user cannot publish nor manage
  def test_cannot_publish_nor_manage
    visitor(:ant)
    item = secure(Item) { items(:collections) }
    assert ! item.can_publish? , "Cannot publish"
    assert ! item.can_manage? , "Cannot manage"
    assert ! item.save , "Save fails"
    assert item.errors[:base], "Errors on base"
    assert_equal "you do not have the rights to do this", item.errors[:base]
  end
  
  # 4. parent changed ? verify 'publish access to new *and* old'
  def test_reference_changed_cannot_pub_in_new
    visitor(:ant)
    # cannot publish in new ref
    item = secure(Item) { items(:bird_jpg) } # can publish in reference
    item[:parent_id] = items_id(:cleanWater) # cannot publish here
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert "invalid reference", item.errors[:parent_id]
  end
  def test_reference_changed_cannot_pub_in_old
    visitor(:ant)
    # cannot publish in old ref
    item = secure(Item) { items(:talk)  } # cannot publish in parent 'secret'
    item[:parent_id] = items_id(:wiki) # can publish here
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
    assert "invalid reference", item.errors[:parent_id]
  end
  def test_reference_changed_ok
    # ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) } # can publish here
    item[:parent_id] = items_id(:wiki) # can publish here
    assert item.save , "Save succeeds"
    assert_equal item[:project_id], items(:wiki).project_id, "Same project as parent"
  end
  
  # 5. validate +rw groups+ :
  #     a. if can_publish? : valid groups
  def test_update_rw_groups_for_publisher_bad_rgroup
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    p = secure(Page) { Page.find(item[:parent_id])}
    assert p.can_publish? , "Can publish in reference" # can publish in reference
    assert item.can_publish? , "Can publish"
    
    # bad rgroup
    item[:inherit  ] = 0
    item[:rgroup_id] = 99999
    assert ! item.save , "Save fails"
    assert item.errors[:rgroup_id] , "Error on rgroup_id"
    assert_equal "unknown group", item.errors[:rgroup_id]
  end
  def test_update_rw_groups_for_publisher_not_in_new_rgroup
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    item[:inherit  ] = 0
    item[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! item.save , "Save fails"
    assert item.errors[:rgroup_id], "Error on rgroup_id"
    assert_equal "unknown group", item.errors[:rgroup_id]
  end
  def test_update_rw_groups_for_publisher_bad_wgroup
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    # bad wgroup
    item[:inherit  ] = 0
    item[:wgroup_id] = 99999
    assert ! item.save , "Save fails"
    assert item.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", item.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_not_in_new_wgroup
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    item[:inherit  ] = 0
    item[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! item.save , "Save fails"
    assert item.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", item.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_ok
    visitor(:tiger)
    item = secure(Item) { items(:lake) }
    # all ok
    item[:inherit  ] = 0
    item[:rgroup_id] = 1
    item[:wgroup_id] = 4
    assert item.save , "Save succeeds"
    assert item.errors.empty? , "Errors empty"
  end
  
  #     b. else (can_manage as item is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
  def hello_ant
    visitor(:ant)
    # create new item
    attrs =  {
    :name => 'hello',
    :parent_id   => items_id(:cleanWater),
    }
    z = secure(Note) { Note.create(attrs) }
    item = secure(Item) { Item.find_by_name('hello') }
    p = secure(Item) { Item.find(item[:parent_id])}
    [z, item, p]
  end
  def test_can_man_cannot_update_pgroup
    z, item, p = hello_ant
    assert ! z.new_record? , "Not a new record"
    assert ! p.can_publish? , "Cannot publish in reference"
    assert p.can_write? , "Can write in reference"
    assert ! item.can_publish? , "Cannot publish"
    assert item.can_manage? , "Can manage"
    
    # cannot change pgroup
    item[:inherit  ] = 0
    item[:pgroup_id] = 1
    assert (item[:pgroup_id] != p.pgroup_id) , "Publish group is different from reference"
    assert ! item.save , "Save fails"
    assert item.errors[:pgroup_id] , "Errors on pgroup_id"
    assert_equal "you cannot change this", item.errors[:pgroup_id]
  end
  def test_can_man_cannot_change_rwgroups
    z, item, p = hello_ant
    # change groups
    item[:inherit  ] = 0
    item[:rgroup_id] = 98984984 # anything
    item[:wgroup_id] = 98984984 # anything
    item[:pgroup_id] = p.pgroup_id # same as reference
    assert ! item.save , "Save fails"
    assert item.errors[:rgroup_id] , "Errors on rgroup_id"
    assert item.errors[:wgroup_id] , "Errors on wgroup_id"
    assert_equal "you cannot change this", item.errors[:rgroup_id]
    assert_equal "you cannot change this", item.errors[:wgroup_id]
  end
  def test_can_man_can_make_private
    z, item, p = hello_ant
    # make private
    item[:inherit  ] = -1 # make private
    item[:rgroup_id] = 98984984 # anything
    item[:wgroup_id] = 98984984 # anything
    item[:pgroup_id] = 98984984 # anything
    assert item.save , "Save succeeds"
    assert_equal 0, item.rgroup_id , "Read group is 0"
    assert_equal 0, item.wgroup_id , "Write group is 0"
    assert_equal 0, item.pgroup_id , "Publish group is 0"
    assert_equal 0, item.pgroup_id , "Inherit mode is 0"
  end
  def test_can_man_cannot_lock_inherit
    z, item, p = hello_ant
    # make private
    item[:inherit  ] = 0 # lock inheritance
    assert ! item.save , "Save fails"
    assert item.errors[:inherit] , "Errors on inherit"
    assert_equal "invalid value", item.errors[:inherit]
  end
  
  def test_can_man_update_attributes
    z, item, p = hello_ant
    # make private
    attrs = { :inherit => -1, :rgroup_id=> 98748987, :wgroup_id => 98984984, :pgroup_id => 98984984 }
    assert item.update_attributes(attrs), "Update attributes succeeds"
    assert_equal 0, item.rgroup_id , "Read group is 0"
    assert_equal 0, item.wgroup_id , "Write group is 0"
    assert_equal 0, item.pgroup_id , "Publish group is 0"
    assert_equal 0, item.inherit , "Inherit mode is 0"
  end
  
  def test_can_man_can_inherit
    z, item, p = hello_ant
    # inherit
    item[:inherit  ] = 1 # inherit
    assert item.save , "Save succeeds"
    assert_equal p.rgroup_id, item.rgroup_id ,    "Read group is same as reference"
    assert_equal p.wgroup_id, item.wgroup_id ,   "Write group is same as reference"
    assert_equal p.pgroup_id, item.pgroup_id , "Publish group is same as reference"
    assert_equal 1, item.inherit , "Inherit mode is 1"
  end
  
  def test_cannot_set_publish_from
    visitor(:tiger)
    item = secure(Item) { items(:lake)  }
    now = Time.now
    old = item.publish_from
    item.publish_from = now
    assert item.save
    assert_equal item.publish_from, old
    item.publish_from = nil
    assert item.save
    assert_not_nil item[:publish_from]
    assert_equal item[:publish_from], old
  end
  
  def test_update_name_publish_group
    visitor(:lion) # owns 'strange'
    item = secure(Item) { items(:strange)  }
    assert item.propose
    visitor(:ant)
    item = secure_drive(Item) { items(:strange)  } # only in pgroup
    item.name = "kali"
    assert item.save
  end
  #     3. removing the item and/or sub-items
  def test_destroy
    visitor(:ant)
    item = secure(Item) { items(:status)  }
    assert !item.destroy, "Cannot destroy"
    assert_equal item.errors[:base], 'you do not have the rights to do this'
  
    visitor(:tiger)
    item = secure(Item) { items(:status)  }
    assert item.destroy, "Can destroy"
  end
end