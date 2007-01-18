require File.dirname(__FILE__) + '/../test_helper'
class PagerDummy < Node
  def self.ksel
    self == PagerDummy ? 'U' : super
  end
end
class SubPagerDummy < PagerDummy
end
class SecureReadTest < Test::Unit::TestCase

  include ZenaTestUnit
  
  def test_fixture_by_id
    assert_equal 1, nodes_id(:zena)
  end
  def test_kpath
    assert_equal Node.kpath, 'N'
    assert_equal Page.kpath, 'NP'
    assert_equal PagerDummy.ksel, 'U'
    assert_equal PagerDummy.kpath, 'NU'
    assert_equal SubPagerDummy.kpath, 'NUS'
  end
  def test_callbacks
    assert Node.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert Page.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert Node.read_inheritable_attribute(:validate_on_create).include?(:node_on_create)
    assert Node.read_inheritable_attribute(:validate_on_update).include?(:node_on_update)
    assert Page.read_inheritable_attribute(:validate_on_create).include?(:node_on_create)
    assert Page.read_inheritable_attribute(:validate_on_update).include?(:node_on_update)
  end
  # SECURE FIND TESTS  ===== TODO CORRECT THESE TEST FROM CHANGES TO RULES ========
  # [user]          Node owner. Can *read*, *write* and (*manage*: if node not published yet or node is private).
  def test_can_rwm_own_private_node
    visitor(:ant)
    node = secure(Node) { nodes(:myLife)  }
    assert_kind_of Node, node
    assert_equal 'myLife', node.name
    assert node.can_read?, "Can read"
    assert node.can_write? , "Can write"
    assert node.private? , "Node is private"
    assert node.can_manage? , "Can manage"
    assert node.can_drive? , "Can manage"
    assert !node.can_visible? , "Cannot make visible changes"
  end
  def test_cannot_view_others_private_nodes
    visitor(:lion)
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { nodes(:myLife)  }}
  end
  def test_owner_but_not_in_rgroup
    visitor(:ant)
    node = secure(Node) { nodes(:proposition)  }
    assert_kind_of Node, node
    assert node.can_read? , "Can read"
    assert node.can_write? , "Can write"
    assert ! node.can_publish? , "Can publish"
  end
  def test_cannot_rwpm_if_not_owner_and_not_in_any_group
    visitor(:ant)
    # not in any group and not owner
    node = nodes(:secret)
    node.set_visitor(visitor_id, visitor_groups, lang)
    assert ! node.can_read? , "Can read"
    assert ! node.can_write? , "Can write"
    assert ! node.can_publish? , "Can publish"
    assert ! node.can_manage? , "Can manage"
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { Node.find(node.id) }}
  end
  
  def test_rgroup_can_read_if_published
    # visitor = public
    # not published, cannot read
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { nodes(:crocodiles)  }}
    # published: can read
    node = secure(Node) { nodes(:lake)  }
    assert_kind_of Node, node
  end
  # write group can only write
  def test_write_group_can_w
    visitor(:tiger)
    node = ""
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { nodes(:strange)  } }
    assert_nothing_raised { node = secure_write(Node) { nodes(:strange)  } }
    assert ! node.can_read? , "Cannot read"
    assert node.can_write? , "Can write"
  end
  # pgroup can only publish
  def test_publish_group_can_rwp
    visitor(:ant)
    node = ""
    ant = users(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { nodes(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure_write(Node) { nodes(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure_drive(Node) { nodes(:strange)  } }
    
    visitor(:lion)
    lion_node = ""
    assert_nothing_raised { lion_node = secure(Node) { nodes(:strange)  } }
    assert lion_node.can_read? , "Owner can read"
    assert lion_node.propose , "Can propose"
    
    visitor(:ant)
    # now node is 'prop', pgroup can see it
    assert_nothing_raised { node = secure(Node) { nodes(:strange)  } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure_write(Node) { nodes(:strange)  } }
    assert_nothing_raised { node = secure_drive(Node) { nodes(:strange)  } }
    assert ! ant.group_ids.include?(node.rgroup_id) , "Visitor is not in rgroup"
    assert ! ant.group_ids.include?(node.wgroup_id) , "Visitor is not in wgroup"
    assert ! (ant.id == node.user_id) , "Visitor is not the owner"
    assert ant.group_ids.include?(node.pgroup_id) , "Visitor is in pgroup"
    assert node.can_publish? , "Can publish"
    assert node.can_read? , "Can read as node is 'proposed'"
    assert ! node.can_write? , "Cannot write"
    assert ! node.can_manage? , "Cannot manage"
  end
  
  def test_public_not_in_rgroup_cannot_rwp
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Node) { nodes(:secret)  } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure_write(Node) { nodes(:secret)  } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure_drive(Node) { nodes(:secret)  } }
    node = nodes(:secret) .set_visitor(1,[1],'en')
    assert ! node.can_read? , "Cannot read"
    assert ! node.can_write? , "Cannot write"
    assert ! node.can_publish? , "Cannot publish"
  end
  def test_pgroup_can_read_unplished_nodes
    # create an unpublished node
    visitor(:lion)
    node = secure(Node) { nodes(:strange)  }
    node = secure(Node) { node.clone }
    node[:publish_from] = nil
    node[:name] = "new_rec"
    assert node.new_record?
    assert node.save
    
    visitor(:ant)
    # node is 'red', cannot see it
    assert_raise(ActiveRecord::RecordNotFound) { node = secure(Page) { Page.find_by_name("new_rec") } }
    
    visitor(:lion)
    assert node.propose , "Can propose node for publication."
    
    visitor(:ant)
    # node can now be seen
    assert_nothing_raised { node = secure(Page) { Page.find_by_name("new_rec") } }
    assert_nil node[:publish_from] , "Not published yet"
  end
end

class SecureCreateTest < Test::Unit::TestCase

  include ZenaTestUnit
  def node_defaults
    {
    :name       => 'hello',
    :parent_id  => 1
    }
  end
  
  # VALIDATE ON CREATE TESTS
  def test_unsecure_new_fails
    visitor(:ant)
    # unsecure creation :
    test_page = Node.new(node_defaults)
    assert ! test_page.save , "Save fails"
    assert_equal "record not secured", test_page.errors[:base]
  end
  def test_secure_new_succeeds
    visitor(:ant)
    test_page = secure(Node) { Node.new(:name=>"yoba", :parent_id=>1) }
    assert test_page.save , "Save succeeds"
  end
  def test_unsecure_create_fails
    visitor(:ant)
    p = Node.create(node_defaults)
    assert p.new_record? , "New record"
    assert_equal "record not secured", p.errors[:base]
  end
  def test_secure_create_succeeds
    visitor(:ant)
    p = secure(Node) { Node.create(node_defaults) }
    assert ! p.new_record? , "Not a new record"
    assert p.id , "Has an id"
  end
  
  # 0. set node.user_id = visitor_id
  def test_owner_is_visitor_on_new
    visitor(:ant)
    test_page = secure(Node) { Node.new(node_defaults) }
    test_page[:user_id] = 99 # try to fool
    assert test_page.save , "Save succeeds"
    assert_equal users_id(:ant), test_page.user_id
  end
  def test_owner_is_visitor_on_create
    visitor(:ant)
    attrs = node_defaults
    attrs[:user_id] = 99
    page = secure(Node) { Node.create(attrs) }
    assert_equal users_id(:ant), page.user_id
  end
  def test_status
    visitor(:tiger)
    node = secure(Node) { Node.new(node_defaults) }
    assert_equal Zena::Status[:red], node.max_status, "New node max_status is 'red'"
    assert_equal Zena::Status[:red], node.v_status, "Version status is 'red'"
    
    assert node.save, "Node saved"
    assert_equal Zena::Status[:red], node.max_status, "Max_status did not change"
    assert node.propose, "Can propose node"
    assert_equal Zena::Status[:prop], node.max_status, "Node#{node[:id]} max_status is now 'prop'"
    assert node.publish, "Can publish node"
    assert_equal Zena::Status[:pub], node.max_status, "node max_status in now 'pub'"
    id = node.id
    visitor(:ant)
    assert_nothing_raised { node = secure(Node) { Node.find(id) } }
    assert node.update_attributes(:v_summary=>'hello my friends'), "Can create a new edition"
    assert_equal Zena::Status[:pub], node.max_status, "Node max_status did not change"
    assert node.propose, "Can propose edition"
    assert_equal Zena::Status[:pub], node.max_status, "Node max_status did not change"
    # TODO continue test when 'remove, replace, rollback, ...' are implemented
  end
  # 2. valid reference (in which the visitor has write access and ref<>self !)
  def test_invalid_reference_cannot_write_in_new
    visitor(:ant)
    attrs = node_defaults
    
    # ant cannot write into secret
    attrs[:parent_id] = nodes_id(:secret)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", z.errors[:parent_id]
  end
  def test_invalid_reference_not_correct_class
    visitor(:ant)
    attrs = node_defaults
    
    # lake is not a Project (Notes use Projects as references)
    attrs[:parent_id] = nodes_id(:lake)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid parent", z.errors[:parent_id]
  end
  def test_no_reference
    # root nodes do not have a parent_id !!
    # reference = self
    visitor(:lion)
    z = secure(Node) { nodes(:zena)  }
    assert_nil z[:parent_id]
    z[:pgroup_id] = 1
    assert z.save, "Can change root group"
  end
  
  def test_circular_reference
    visitor(:tiger)
    node = secure(Node) { nodes(:projects)  }
    node[:parent_id] = nodes_id(:status)
    assert ! node.save, 'Save fails'
    assert_equal node.errors[:parent_id], 'circular reference'
  end
  
  def test_existing_circular_reference
    visitor(:tiger)
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:cleanWater)} WHERE id=#{nodes_id(:projects)}"
    node = secure(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:projects)
    assert ! node.save, 'Save fails'
    assert_equal node.errors[:parent_id], 'circular reference'
  end
  
  def test_valid_without_circular
    visitor(:tiger)
    node = secure(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:zena)
    assert node.save, 'Save succeeds'
  end
  
  def test_set_reference_for_root
    visitor(:tiger)
    node = secure(Node) { nodes(:zena)  }
    node.name = 'bob'
    assert node.save
    node[:parent_id] = nodes_id(:status)
    assert ! node.save, 'Save fails'
    assert_equal 'parent must be empty for root', node.errors[:parent_id]
  end
  
  def test_valid_reference
    visitor(:ant)
    attrs = node_defaults
    
    # ok
    attrs[:parent_id] = nodes_id(:cleanWater)
    z = secure(Note) { Note.create(attrs) }
    assert ! z.new_record? , "Not a new record"
    assert z.errors.empty? , "No errors"
  end
  
  # 3. validate +publish_group+ value (same as parent or ref.can_publish? and valid)
  def test_valid_publish_group_cannot_change_if_not_ref_can_publish
    visitor(:ant)
    attrs = node_defaults
    
    # can create node in cleanWater
    cw = nodes(:cleanWater)
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
    attrs = node_defaults
    
    # can publish in ref 'wiki', but is not in group managers
    attrs[:parent_id] = nodes_id(:wiki)
    attrs[:pgroup_id] = groups_id(:managers)
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:pgroup_id] , "Errors on pgroup_id"
    assert_equal "unknown group", z.errors[:pgroup_id]
  end
  def test_valid_publish_group
    visitor(:ant)
    attrs = node_defaults
    wiki = nodes(:wiki)
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
  def test_can_vis_bad_rgroup
    visitor(:tiger)
    attrs = node_defaults

    p = secure(Node) { Node.find(attrs[:parent_id])}
    assert p.can_visible? , "Can publish"
    
    # bad rgroup
    attrs[:rgroup_id] = 99999
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:rgroup_id] , "Error on rgroup_id"
    assert_equal "unknown group", z.errors[:rgroup_id]
  end
  def test_can_vis_bad_rgroup_visitor_not_in_group
    visitor(:tiger)
    attrs = node_defaults
    attrs[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:rgroup_id], "Error on rgroup_id"
    assert_equal "unknown group", z.errors[:rgroup_id]
  end
  def test_can_vis_bad_wgroup
    visitor(:tiger)
    attrs = node_defaults
    # bad wgroup
    attrs[:wgroup_id] = 99999
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", z.errors[:wgroup_id]
  end
  def test_can_vis_bad_wgroup_visitor_not_in_group
    visitor(:tiger)
    attrs = node_defaults
    
    attrs[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    z = secure(Note) { Note.create(attrs) }
    assert z.new_record? , "New record"
    assert z.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", z.errors[:wgroup_id]
  end
  def test_can_vis_rwgroups_ok
    visitor(:tiger)
    attrs = node_defaults
    zena = nodes(:zena)
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
  
  #     b. else (can_manage as node is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
  def test_can_man_cannot_change_pgroup
    visitor(:ant)
    attrs = node_defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
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
    attrs = node_defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
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
    attrs = node_defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
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
    attrs = node_defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
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
  # testing is done in page_test or node_test
end

class SecureUpdateTest < Test::Unit::TestCase

  include ZenaTestUnit
  
  # VALIDATE ON UPDATE TESTS
  # 1. if pgroup changed from old, make sure user could do this and new group is valid
  def test_pgroup_changed_cannot_visible
    # cannot visible
    visitor(:ant)
    node = secure(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert ! node.can_visible? , "Cannot make visible changes"
    node.pgroup_id = 1
    assert ! node.save , "Save fails"
    assert node.errors[:base] , "Errors on base"
    assert "you do not have the rights to do this", node.errors[:base]
  end
  def test_inherit_changed_cannot_visible
    # cannot visible
    visitor(:ant)
    parent = nodes(:cleanWater)
    node = secure(Page) { Page.create(:parent_id=>parent[:id], :name=>'thing')}
    assert_kind_of Node, node
    assert ! node.new_record?  , "Not a new record"
    assert ! node.can_visible? , "Cannot make visible changes"
    assert node.can_manage? , "Can manage"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    node.inherit = 0
    assert ! node.save , "Save fails"
    assert node.errors[:inherit] , "Errors on inherit"
    assert "invalid value", node.errors[:inherit]
  end
  def test_pgroup_changed_bad_pgroup_visitor_not_in_group
    # bad pgroup
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert node.can_visible? , "Can visible"
    node[:inherit  ] = 0
    node[:pgroup_id] = 2
    assert ! node.save , "Save fails"
    assert node.errors[:pgroup_id] , "Errors on pgroup_id"
    assert "unknown group", node.errors[:pgroup_id]
  end
  def test_pgroup_changed_ok
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert_kind_of Contact, node
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    node[:inherit  ] = 0
    node[:pgroup_id] = 1
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
  end
  def test_pgroup_cannot_nil_unless_owner
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert_equal users_id(:ant), node[:user_id]
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal 4, node.pgroup_id
    node[:inherit  ] = 0
    node[:pgroup_id] = nil
    assert !node.save , "Save fails"
    assert node.errors[:inherit]
  end
  def test_pgroup_can_nil_if_owner
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:people) }
    assert_equal users_id(:tiger), node[:user_id]
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal 4, node.pgroup_id
    node[:inherit  ] = 0
    node[:pgroup_id] = nil
    assert node.save , "Save succeeds"
    assert node.private?, "Node is now private"
  end
  def test_rgroup_change_rgroup_with_nil_ok
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal 1, node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = nil
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
    assert_equal 0, node.rgroup_id
    assert !node.private?, "Not private"
  end
  def test_rgroup_change_rgroup_with_0_ok
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal 1, node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = 0
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
    assert_equal 0, node.rgroup_id
  end
  def test_rgroup_change_to_private_with_empty_ok
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert node.can_visible? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal 1, node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = ''
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
    assert_equal 0, node.rgroup_id
  end
  def test_group_changed_children_too
    visitor(:tiger)
    node = secure(Node) { nodes(:cleanWater)  }
    node[:inherit  ] = 0
    node[:rgroup_id] = 3
    assert node.save , "Save succeeds"
    assert_equal 3, node[:rgroup_id], "Read group changed"
    assert_equal 3, nodes(:status).rgroup_id, "Child read group changed"
    assert_equal 3, nodes(:water_pdf).rgroup_id, "Child read group changed"
    assert_equal 3, nodes(:lake_jpg).rgroup_id, "Grandchild read group changed"
    assert_equal 4, nodes(:bananas).rgroup_id, "Not inherited child: rgroup not changed"
  end
  
  
  def test_template_changed_children_too
    visitor(:tiger)
    node = secure(Node) { nodes(:cleanWater)  }
    node[:inherit  ] = 0
    node[:template] = 'wiki'
    assert node.save , "Save succeeds"
    assert_equal 'wiki', node[:template], "Template changed"
    assert_equal 'wiki', nodes(:status    ).template, "Child template group changed"
    assert_equal 'wiki', nodes(:water_pdf ).template, "Child template group changed"
    assert_equal 'wiki', nodes(:lake_jpg  ).template, "Grandchild template group changed"
    assert_equal 'default', nodes(:bananas).template, "Not inherited child: template not changed"
  end
  
  # 2. if owner changed from old, make sure only a user in 'admin' can do this
  def test_owner_changed_visitor_not_admin
    # not in 'admin' group
    visitor(:tiger)
    node = secure(Node) { nodes(:bananas) }
    assert_kind_of Node, node
    assert_equal users_id(:lion), node.user_id
    node.user_id = users_id(:tiger)
    assert ! node.save , "Save fails"
    assert node.errors[:user_id] , "Errors on user_id"
    assert_equal "you cannot change this", node.errors[:user_id]
  end
  def test_owner_changed_bad_user
    # cannot write in new contact
    visitor(:lion)
    node = secure(Node) { nodes(:bananas) }
    assert_kind_of Node, node
    assert_equal users_id(:lion), node.user_id
    node.user_id = 99
    assert ! node.save , "Save fails"
    assert node.errors[:user_id] , "Errors on user_id"
    assert_equal "unknown user", node.errors[:user_id]
  end
  def test_owner_changed_ok
    visitor(:lion)
    node = secure(Node) { nodes(:bananas) }
    node.user_id = users_id(:tiger)
    assert node.save , "Save succeeds"
    node.reload
    assert_equal users_id(:tiger), node.user_id
  end
  
  # 3. error if user cannot visible nor manage
  def test_cannot_visible_nor_manage
    visitor(:ant)
    node = secure(Node) { nodes(:collections) }
    assert ! node.can_visible? , "Cannot visible"
    assert ! node.can_manage? , "Cannot manage"
    assert ! node.save , "Save fails"
    assert node.errors[:base], "Errors on base"
    assert_equal "you do not have the rights to do this", node.errors[:base]
  end
  
  # 4. parent changed ? verify 'visible access to new *and* old'
  def test_reference_changed_cannot_pub_in_new
    visitor(:ant)
    # cannot visible in new ref
    node = secure(Node) { nodes(:bird_jpg) } # can visible in reference
    node[:parent_id] = nodes_id(:cleanWater) # cannot visible here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert "invalid reference", node.errors[:parent_id]
  end
  def test_reference_changed_cannot_pub_in_old
    visitor(:ant)
    # cannot visible in old ref
    node = secure(Node) { nodes(:talk)  } # cannot visible in parent 'secret'
    node[:parent_id] = nodes_id(:wiki) # can visible here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert "invalid reference", node.errors[:parent_id]
  end
  def test_reference_changed_ok
    # ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) } # can visible here
    node[:parent_id] = nodes_id(:wiki) # can visible here
    assert node.save , "Save succeeds"
    assert_equal node[:project_id], nodes(:wiki).project_id, "Same project as parent"
  end
  
  # 5. validate +rw groups+ :
  #     a. can change to 'inherit' if can_drive?
  #     b. can change to 'private' if can_manage?
  #     c. can change to 'custom'  if can_visible?
  def test_update_rw_groups_for_publisher_bad_rgroup
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    p = secure(Page) { Page.find(node[:parent_id])}
    assert p.can_visible? , "Can visible in reference" # can visible in reference
    assert node.can_visible? , "Can visible"
    
    # bad rgroup
    node[:inherit  ] = 0
    node[:rgroup_id] = 99999
    assert ! node.save , "Save fails"
    assert node.errors[:rgroup_id] , "Error on rgroup_id"
    assert_equal "unknown group", node.errors[:rgroup_id]
  end
  def test_update_rw_groups_for_publisher_not_in_new_rgroup
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    node[:inherit  ] = 0
    node[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! node.save , "Save fails"
    assert node.errors[:rgroup_id], "Error on rgroup_id"
    assert_equal "unknown group", node.errors[:rgroup_id]
  end
  def test_update_rw_groups_for_publisher_bad_wgroup
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    # bad wgroup
    node[:inherit  ] = 0
    node[:wgroup_id] = 99999
    assert ! node.save , "Save fails"
    assert node.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", node.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_not_in_new_wgroup
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    node[:inherit  ] = 0
    node[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! node.save , "Save fails"
    assert node.errors[:wgroup_id] , "Error on wgroup_id"
    assert_equal "unknown group", node.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_ok
    visitor(:tiger)
    node = secure(Node) { nodes(:lake) }
    # all ok
    node[:inherit  ] = 0
    node[:rgroup_id] = 1
    node[:wgroup_id] = 4
    assert node.save , "Save succeeds"
    assert node.errors.empty? , "Errors empty"
  end
  
  #     a. can change to 'inherit' if can_drive?
  #     b. can change to 'private' if can_manage?
  #     c. can change to 'custom'  if can_visible?
  def hello_ant
    visitor(:ant)
    # create new node
    attrs =  {
    :name => 'hello',
    :parent_id   => nodes_id(:cleanWater),
    }
    node = secure(Note) { Note.create(attrs) }
    ref  = secure(Node) { Node.find(node[:parent_id])}
    [node, ref]
  end
  def test_can_man_cannot_custom_inherit
    node, ref = hello_ant
    assert ! node.new_record? , "Not a new record"
    assert ! ref.can_visible? , "Cannot visible in reference"
    assert ref.can_write? , "Can write in reference"
    assert ! node.can_visible? , "Cannot visible"
    assert node.can_manage? , "Can manage"
    
    # cannot change inherit
    node[:inherit  ] = 0
    assert ! node.save , "Save fails"
    assert node.errors[:inherit] , "Errors on pgroup_id"
    assert_equal "you cannot change this", node.errors[:inherit]
  end
  def test_can_man_can_make_private
    node, ref = hello_ant
    # make private
    node[:inherit  ] = -1 # make private
    node[:rgroup_id] = 98984984 # anything
    node[:wgroup_id] = 98984984 # anything
    node[:pgroup_id] = 98984984 # anything
    assert node.save , "Save succeeds"
    assert_equal 0, node.rgroup_id , "Read group is 0"
    assert_equal 0, node.wgroup_id , "Write group is 0"
    assert_equal 0, node.pgroup_id , "Publish group is 0"
    assert_equal 0, node.pgroup_id , "Inherit mode is 0"
  end
  def test_can_man_cannot_lock_inherit
    node, ref = hello_ant
    # make private
    node[:inherit  ] = 0 # lock inheritance
    assert ! node.save , "Save fails"
    assert node.errors[:inherit] , "Errors on inherit"
    assert_equal "you cannot change this", node.errors[:inherit]
  end
  
  def test_can_man_update_inherit
    node, ref = hello_ant
    assert node.update_attributes(:inherit=>-1)
    assert node.publish
    assert node.can_drive?, "Can drive"
    assert !node.can_visible?, "Cannot make visible changes"
    assert_equal Zena::Status[:pub], node.max_status
    # cannot change rights now
    assert !node.update_attributes(:inherit=>1)
    node.errors.clear
    assert node.unpublish
    assert node.can_drive?, "Can drive"
    # can change rights now
    assert node.update_attributes(:inherit=>1)
  end
  
  #     a. can change to 'inherit' if can_drive?
  #     b. can change to 'private' if can_manage?
  #     c. can change to 'custom'  if can_visible?
  def test_can_man_update_attributes
    node, ref = hello_ant
    # make private
    attrs = { :inherit => -1, :rgroup_id=> 98748987, :wgroup_id => 98984984, :pgroup_id => 98984984 }
    assert node.update_attributes(attrs), "Update attributes succeeds"
    assert_equal 0, node.rgroup_id , "Read group is 0"
    assert_equal 0, node.wgroup_id , "Write group is 0"
    assert_equal 0, node.pgroup_id , "Publish group is 0"
    assert_equal -1, node.inherit , "Inherit mode is -1"
  end
  
  def test_can_man_can_inherit
    node, ref = hello_ant
    # inherit
    node[:inherit  ] = 1 # inherit
    assert node.save , "Save succeeds"
    assert_equal ref.rgroup_id, node.rgroup_id ,    "Read group is same as reference"
    assert_equal ref.wgroup_id, node.wgroup_id ,   "Write group is same as reference"
    assert_equal ref.pgroup_id, node.pgroup_id , "Publish group is same as reference"
    assert_equal 1, node.inherit , "Inherit mode is 1"
  end
  
  def test_cannot_set_publish_from
    visitor(:tiger)
    node = secure(Node) { nodes(:lake)  }
    now = Time.now
    old = node.publish_from
    node.publish_from = now
    assert node.save
    assert_equal node.publish_from, old
    node.publish_from = nil
    assert node.save
    assert_not_nil node[:publish_from]
    assert_equal node[:publish_from], old
  end
  
  def test_update_name_publish_group
    visitor(:lion) # owns 'strange'
    node = secure(Node) { nodes(:strange)  }
    assert node.propose
    visitor(:ant)
    node = secure_drive(Node) { nodes(:strange)  } # only in pgroup
    node.name = "kali"
    assert node.save
  end
  #     3. removing the node and/or sub-nodes
  def test_destroy
    visitor(:ant)
    node = secure(Node) { nodes(:status)  }
    assert !node.destroy, "Cannot destroy"
    assert_equal node.errors[:base], 'you do not have the rights to do this'
  
    visitor(:tiger)
    node = secure(Node) { nodes(:status)  }
    assert node.destroy, "Can destroy"
  end
end