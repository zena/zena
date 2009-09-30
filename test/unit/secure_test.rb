require 'test_helper'

class PagerDummy < Node
  def self.ksel
    self == PagerDummy ? 'U' : super
  end
end

class SubPagerDummy < PagerDummy
end

class SecureTest < Zena::Unit::TestCase

  context 'A class path (kpath)' do
    should 'represent the class hierarchy' do
      assert_equal 'N', Node.kpath
      assert_equal 'NP', Page.kpath
      assert_equal 'U', PagerDummy.ksel
      assert_equal 'NU', PagerDummy.kpath
      assert_equal 'NUS', SubPagerDummy.kpath
    end
  end

  context 'A visitor not in any access groups of a node' do
    setup do
      login(:anon)
    end

    should 'raise an exception when trying to find the node with secure! read scope' do
      assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { nodes(:secret) }}
    end

    should 'raise an exception when trying to find the node with secure! write scope' do
      assert_raise(ActiveRecord::RecordNotFound) { secure_write!(Node) { nodes(:secret) }}
    end

    should 'raise an exception when trying to find the node with secure! drive scope' do
      assert_raise(ActiveRecord::RecordNotFound) { secure_drive!(Node) { nodes(:secret) }}
    end

    should 'receive nil when calling secure read' do
      node = nil
      assert_nothing_raised { node = secure(Node) { nodes(:secret)  }}
      assert_nil node
    end

    should 'receive nil when calling secure write' do
      node = nil
      assert_nothing_raised { node = secure_write(Node) { nodes(:secret)  }}
      assert_nil node
    end

    should 'receive nil when calling secure drive' do
      node = nil
      assert_nothing_raised { node = secure_drive(Node) { nodes(:secret)  }}
      assert_nil node
    end

    should 'receive 0 when counting nodes with any secure scope' do
      assert_equal 0, secure!(Node)       { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
      assert_equal 0, secure(Node)        { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
      assert_equal 0, secure_write!(Node) { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
      assert_equal 0, secure_write(Node)  { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
      assert_equal 0, secure_drive!(Node) { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
      assert_equal 0, secure_drive(Node)  { Node.count(:conditions => ['id = ?', nodes_id(:secret)])}
    end

    context 'loaded without secure' do
      setup do
        @node = nodes(:secret)
        @visitor.visit(@node)
      end

      should 'receive false when asking can_read?' do
        assert !@node.can_read?
      end

      should 'receive false when asking can_write?' do
        assert !@node.can_write?
      end

      should 'receive false when asking can_drive?' do
        assert !@node.can_drive?
      end
    end
  end # A visitor not in any access groups

  context 'A visitor counting nodes' do
    setup do
      login(:ant)
    end

    should 'only see nodes where she is a member of the read group when using secure' do
      # 'strange' not seen
      assert_equal 4, secure!(Node) { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
      assert_equal 4, secure(Node)  { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
    end

    should 'only see nodes where she is a member of the write group when using secure_write' do
      assert_equal 4, secure_write!(Node) { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
      assert_equal 4, secure_write(Node)  { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
    end

    should 'only see nodes where she is a member of the drive group when using secure_drive' do
      assert_equal 1, secure_drive!(Node) { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
      assert_equal 1, secure_drive(Node)  { Node.count(:conditions => ['parent_id = ?', nodes_id(:collections)])}
    end

    should 'see redactions if she is a member of the write group' do
      assert_equal 7, secure(Node) { Node.count(:conditions => ['parent_id = ?', nodes_id(:cleanWater)])}
    end

    should 'not see the node even if she is the owner' do
      # 'proposition' in secret not seen
      assert_equal 1, secure(Node) { Node.count(:conditions => ['parent_id = ?', nodes_id(:secret)])}
    end
  end # A visitor counting nodes

  context 'A visitor only in the read group' do
    setup do
      login(:anon)
    end

    should 'not see a node that is not published yet' do
      assert_nil secure(Node) { nodes(:crocodiles) }
    end

    should 'see published nodes' do
      assert node = secure(Node) { nodes(:cleanWater) }
    end

    context 'trying to see a future publication' do
      setup do
        set_date(:status, :days => 1, :fld => 'publish_from')
      end

      should 'see nothing' do
        assert_nil secure(Node) { nodes(:status) }
      end
    end
  end # A visitor only in the read group


  context 'A visitor only in the write group' do
    setup do
      login(:ant)
      ids = [:bananas, :crocodiles].map {|r| nodes_id(r)}.join(',')
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:managers)}, wgroup_id = #{groups_id(:workers)}, pgroup_id = #{groups_id(:managers)} WHERE id IN (#{ids})"
    end

    should 'see a node that is not published yet' do
      assert secure(Node) { nodes(:crocodiles) }
    end

    should 'see published nodes' do
      assert secure(Node) { nodes(:bananas) }
    end

    context 'that is a user' do
      should 'be able to write redactions' do
        node = secure(Node) { nodes(:bananas) }
        assert node.can_write?
        assert node.update_attributes(:v_title => 'max havelaar')
        node = secure(Node) { nodes(:bananas) } # reload
        assert_equal 'max havelaar', node.version.title
      end
    end

    context 'that is not a user' do
      setup do
        visitor.status = User::Status[:commentator]
      end

      should 'not be able to write redactions' do
        node = secure(Node) { nodes(:bananas) }
        assert !node.can_write?
        assert !node.update_attributes(:v_title => 'max havelaar')
      end

      should 'see a node that is not published yet' do
        assert secure(Node) { nodes(:crocodiles) }
      end
    end

    context 'trying to see a future publication' do
      setup do
        set_date(:bananas, :days => 1, :fld => 'publish_from')
      end

      should 'see it' do
        assert secure(Node) { nodes(:bananas) }
      end
    end
  end # A visitor only in the write group

  context 'A visitor only in the drive group' do
    setup do
      login(:ant)
      ids = [:bananas, :crocodiles].map {|r| nodes_id(r)}.join(',')
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:managers)}, wgroup_id = #{groups_id(:managers)}, pgroup_id = #{groups_id(:workers)} WHERE id IN (#{ids})"
    end

    should 'not see a node that is not published yet' do
      assert_nil secure(Node) { nodes(:crocodiles) }
    end

    should 'not see published nodes' do
      assert_nil secure(Node) { nodes(:bananas) }
    end
  end # A visitor only in the drive group

  context 'A visitor in the read and drive groups' do
    setup do
      login(:ant)
      ids = [:bananas, :crocodiles].map {|r| nodes_id(r)}.join(',')
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:workers)}, wgroup_id = #{groups_id(:managers)}, pgroup_id = #{groups_id(:workers)} WHERE id IN (#{ids})"
    end

    should 'not be able to write' do
      node = secure!(Node) { nodes(:bananas) }
      assert !node.can_write?
      assert !node.update_attributes(:v_title => 'Banana republic')
    end

    should 'not be able to create sub-nodes' do
      node = secure!(Node) { Node.create(defaults.merge(:parent_id => nodes_id(:bananas))) }
      assert node.new_record?
      assert_equal 'You do not have the rights to edit', node.errors[:base]
    end

    should 'be able to drive' do
      node = secure!(Node) { nodes(:bananas) }
      assert node.can_drive?
      assert node.update_attributes(:name => 'NamWa')
    end
  end # A visitor in the read and drive groups


  def defaults
    { :name       => 'hello',
      :parent_id  => nodes_id(:zena) }
  end

  context 'A visitor in the read and write groups' do
    setup do
      login(:ant)
    end

    context 'without secure' do
      should 'not be able to build new children' do
        node = Node.new(defaults)
        assert !node.save
        assert_equal 'record not secured', node.errors[:base]
      end

      should 'not be able to create new children' do
        node = Node.create(defaults)
        assert node.new_record?
        assert_equal 'record not secured', node.errors[:base]
      end
    end

    should 'be able to build children nodes' do
      node = secure(Node) { Node.new(defaults) }
      assert_difference('Node.count', 1) do
        assert_difference('Version.count', 1) do
          assert node.save
        end
      end
    end

    should 'be able to create child nodes' do
      assert_difference('Node.count', 1) do
        assert_difference('Version.count', 1) do
          assert node = secure(Node) { Node.create(defaults) }
          assert !node.new_record?
        end
      end
    end

    should 'not be allowed to create child nodes with custom rights' do
      node = secure(Node) { Node.create(defaults.merge(:inherit => 0, :wgroup_id => groups_id(:public))) }
      assert node.new_record?
      assert node.errors[:inherit]
      assert node.errors[:wgroup_id]
    end

    context 'creating a new node' do
      setup do
        @node = secure(Node) { Node.create(defaults) }
      end

      should 'become owner of node and version' do
        assert_equal visitor.id, @node.user_id
        assert_equal visitor.id, @node.version.user_id
      end

      should 'see a draft' do
        assert @node.draft?
      end
    end
  end # A visitor in the read and write groups

  context 'A visitor in the drive group' do
    setup do
      login(:tiger)
    end

    should 'be able to move node' do
      node = secure!(Node) { nodes(:projects) }
      node.parent_id = nodes_id(:collections)
      assert node.save
    end

    should 'not be allowed to create circular references' do
      # status is a child of projects/cleanWater
      node = secure!(Node) { nodes(:projects) }
      assert !node.update_attributes(:parent_id => nodes_id(:status))
      assert_equal 'circular reference', node.errors[:parent_id]
    end

    should 'not be allowed to insert into an existing circular reference' do
      Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:cleanWater)} WHERE id=#{nodes_id(:projects)}"
      node = secure!(Node) { nodes(:status)  }
      assert !node.update_attributes(:parent_id => nodes_id(:projects))
      assert_equal 'circular reference', node.errors[:parent_id]
    end

    should 'be allowed to change groups even if she has no rights in the parent' do
      login(:ant) # does not have any rights on talk's parent node (secret)
      node = secure!(Node) { nodes(:talk) }
      node.update_attributes(:pgroup_id => groups_id(:public))
    end

    should 'not be allowed to set a group she is not in' do
      login(:ant) # does not have any rights on talk's parent node (secret)
      node = secure!(Node) { nodes(:talk) }
      assert !node.update_attributes(:rgroup_id => groups_id(:admin))
      assert_equal 'unknown group', node.errors[:rgroup_id]
    end

    should 'not change group without explicitely changing inherit mode' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:rgroup_id => groups_id(:managers))
      assert_equal 'cannot be changed without changing inherit mode', node.errors[:rgroup_id]
    end
  end


  def test_invalid_drive_group_visitor_not_in_group_set
    login(:ant)
    attrs = defaults

    # can publish in ref 'wiki', but is not in group managers
    attrs[:parent_id] = nodes_id(:wiki)
    attrs[:pgroup_id] = groups_id(:managers)
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:pgroup_id].any?
    assert_equal 'unknown group', note.errors[:pgroup_id]
  end
  def test_valid_drive_group
    login(:ant)
    attrs = defaults
    wiki = nodes(:wiki)
    attrs[:parent_id] = wiki[:id]
    # ant is in the 'site' group, all should be ok
    attrs[:pgroup_id] = groups_id(:workers)
    z = secure!(Note) { Note.create(attrs) }
    assert ! z.new_record? , "Not a new record"
    assert z.errors.empty? , "No errors"
    assert_equal wiki[:rgroup_id], z[:rgroup_id] , "Same rgroup as parent"
    assert_equal wiki[:wgroup_id], z[:wgroup_id] , "Same wgroup as parent"
    assert_equal groups_id(:workers), z[:pgroup_id] , "New pgroup set"
  end

  # 4. validate +rw groups+ :
  #     a. if can_publish? : valid groups
  def test_can_drive_bad_rgroup
    login(:tiger)
    attrs = defaults

    p = secure!(Node) { Node.find(attrs[:parent_id])}
    assert p.can_drive? , "Can publish"

    # bad rgroup or tiger not in admin
    [99999, groups_id(:admin)].each do |grp|
      attrs[:rgroup_id] = grp
      note = secure!(Note) { Note.create(attrs) }
      assert note.new_record?
      assert note.errors[:rgroup_id].any?
      assert_equal 'unknown group', note.errors[:rgroup_id]
    end
  end

  def test_can_drive_bad_rgroup_visitor_not_in_group
    login(:tiger)
    attrs = defaults
    attrs[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:rgroup_id].any?
    assert_equal 'unknown group', note.errors[:rgroup_id]
  end
  def test_can_drive_bad_wgroup
    login(:tiger)
    attrs = defaults
    # bad wgroup
    attrs[:wgroup_id] = 99999
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:wgroup_id].any?
    assert_equal 'unknown group', note.errors[:wgroup_id]
  end

  def test_can_drive_bad_wgroup_visitor_not_in_group
    login(:tiger)
    attrs = defaults

    attrs[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:wgroup_id].any?
    assert_equal 'unknown group', note.errors[:wgroup_id]
  end

  def test_can_drive_rwgroups_ok
    login(:tiger)
    attrs = defaults
    zena = nodes(:zena)
    attrs[:parent_id] = zena[:id]
    # all ok
    attrs[:wgroup_id] = groups_id(:managers)
    note = secure!(Note) { Note.create(attrs) }
    err note

    assert ! note.new_record?
    assert note.errors.empty?
    assert_equal zena[:rgroup_id], note[:rgroup_id] , "Same rgroup as parent"
    assert_equal groups_id(:managers), note[:wgroup_id] , "New wgroup set"
    assert_equal zena[:pgroup_id], note[:pgroup_id] , "Same pgroup_id as parent"
  end

  #     b. else (can_manage as node is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
  def test_can_man_cannot_change_pgroup
    login(:ant)
    attrs = defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
    p = secure!(Project) { Project.find(attrs[:parent_id])}
    assert ! p.can_publish? , "Cannot publish in reference"
    assert p.can_write? , "Can write in reference"

    # cannot change pgroup
    attrs[:pgroup_id] = groups_id(:public)
    assert (attrs[:pgroup_id] != p.pgroup_id) , "Publish group is different from reference"
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:pgroup_id].any?
    assert_equal 'you cannot change this', note.errors[:pgroup_id]
  end
  def test_can_man_cannot_change_rw_groups
    login(:ant)
    attrs = defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
    p = secure!(Project) { Project.find(attrs[:parent_id])}

    # change groups
    attrs[:rgroup_id] = 98984984 # anything
    attrs[:wgroup_id] = 98984984 # anything
    attrs[:pgroup_id] = p.pgroup_id # same as reference
    note = secure!(Note) { Note.create(attrs) }
    assert note.new_record?
    assert note.errors[:rgroup_id].any?
    assert note.errors[:wgroup_id].any?
    assert_equal 'you cannot change this', note.errors[:rgroup_id]
    assert_equal 'you cannot change this', note.errors[:wgroup_id]
  end

  def test_can_man_can_inherit_rwp_groups
    login(:ant)
    attrs = defaults

    attrs[:parent_id] = nodes_id(:zena) # ant can write but not publish here
    p = secure!(Project) { Project.find(attrs[:parent_id])}
    # inherit
    attrs[:inherit  ] = 1
    attrs[:rgroup_id] = 98449484 # anything
    attrs[:wgroup_id] = nil # anything
    attrs[:pgroup_id] = 98984984 # anything
    note = secure!(Note) { Note.create(attrs) }
    assert ! note.new_record? , "Not a new record"
    assert_equal p.rgroup_id, note.rgroup_id ,    "Read group is same as reference"
    assert_equal p.wgroup_id, note.wgroup_id ,   "Write group is same as reference"
    assert_equal p.pgroup_id, note.pgroup_id , "Publish group is same as reference"
  end
  # 5. validate the rest
  # testing is done in page_test or node_test
end

class SecureUpdateTest < Zena::Unit::TestCase

  def create_simple_note(opts={})
    login(opts[:login] || :ant)
    # create new node
    attrs =  {
      :name => 'hello',
      :parent_id   => nodes_id(:cleanWater)
    }.merge(opts[:node] || {})

    node = secure!(Note) { Note.create(attrs) }

    ref  = secure!(Node) { Node.find_by_id(attrs[:parent_id])}

    [node, ref]
  end

  # VALIDATE ON UPDATE TESTS
  # 1. if pgroup changed from old, make sure user could do this and new group is valid
  def test_pgroup_changed_cannot_visible
    # cannot visible
    login(:ant)
    node = secure!(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert ! node.can_drive? , "Cannot make visible changes"
    node.pgroup_id = groups_id(:public)
    assert ! node.save , "Save fails"
    assert node.errors[:base].any?
    assert ['you do not have the rights to do this'], node.errors[:base]
  end
  def test_inherit_changed_cannot_visible
    # cannot visible
    login(:ant)
    parent = nodes(:cleanWater)
    node = secure!(Page) { Page.create(:parent_id=>parent[:id], :name=>'thing')}
    assert_kind_of Node, node
    assert ! node.new_record?  , "Not a new record"
    assert ! node.can_drive? , "Cannot make visible changes"
    assert node.can_drive? , "Can manage"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    node.inherit = 0
    assert ! node.save , "Save fails"
    assert node.errors[:inherit].any?
    assert ['invalid value'], node.errors[:inherit]
  end
  def test_pgroup_changed_bad_pgroup_visitor_not_in_group
    # bad pgroup
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert node.can_drive? , "Can visible"
    node[:inherit  ] = 0
    node[:pgroup_id] = groups_id(:admin)
    assert ! node.save , "Save fails"
    assert node.errors[:pgroup_id].any?
    assert ['unknown group'], node.errors[:pgroup_id]
  end
  def test_pgroup_changed_ok
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert_kind_of Contact, node
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    node[:inherit  ] = 0
    node[:pgroup_id] = groups_id(:public)
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
  end
  def test_pgroup_cannot_nil_unless_owner
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert_equal users_id(:ant), node[:user_id]
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal groups_id(:managers), node.pgroup_id
    node[:inherit  ] = 0
    node[:pgroup_id] = nil
    assert !node.save , "Save fails"
    assert node.errors[:inherit].any?
  end

  def test_pgroup_can_nil_if_owner
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:people) }
    assert_equal users_id(:tiger), node[:user_id]
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal groups_id(:managers), node.pgroup_id
    node[:inherit  ] = 0
    node[:pgroup_id] = nil
    assert !node.save
    assert node.errors[:pgroup_id]
  end

  def test_cannot_change_rgroup_with_nil
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal groups_id(:public), node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = nil
    assert !node.save
    assert node.errors[:rgroup_id]
  end

  def test_rgroup_change_rgroup_with_0_ok
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal groups_id(:public), node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = 0
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
    assert_equal 0, node.rgroup_id
  end
  def test_rgroup_change_to_private_with_empty_ok
    # ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert_kind_of Node, node
    assert node.can_drive? , "Can visible"
    assert_equal 1, node.inherit , "Inherit mode is 1"
    assert_equal groups_id(:public), node.rgroup_id
    node[:inherit  ] = 0
    node[:rgroup_id] = ''
    assert node.save , "Save succeeds"
    assert_equal 0, node.inherit , "Inherit mode is 0"
    assert_equal 0, node.rgroup_id
  end
  def test_group_changed_children_too
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater)  }
    node[:inherit  ] = 0
    node[:rgroup_id] = groups_id(:workers)
    assert node.save , "Save succeeds"
    assert_equal groups_id(:workers), node[:rgroup_id], "Read group changed"
    assert_equal groups_id(:workers), nodes(:status).rgroup_id, "Child read group changed"
    assert_equal groups_id(:workers), nodes(:water_pdf).rgroup_id, "Child read group changed"
    assert_equal groups_id(:workers), nodes(:lake_jpg).rgroup_id, "Grandchild read group changed"
    assert_equal groups_id(:managers), nodes(:bananas).rgroup_id, "Not inherited child: rgroup not changed"
  end

  def test_reference_changed_rights_inherited
    login(:lion)
    node = secure!(Node) { nodes(:zena) }
    assert node.update_attributes(:rgroup_id => groups_id(:workers), :wgroup_id => groups_id(:workers), :pgroup_id => groups_id(:workers), :skin => "wiki")
    node = secure!(Node) { nodes(:cleanWater) }
    assert node.update_attributes(:inherit => 0, :rgroup_id => groups_id(:admin), :wgroup_id => groups_id(:admin), :pgroup_id => groups_id(:admin), :skin => "default")
    node = secure!(Node) { nodes(:status) }
    assert_equal groups_id(:admin), node.rgroup_id
    assert_equal groups_id(:admin), node.wgroup_id
    assert_equal groups_id(:admin), node.pgroup_id
    assert_equal "default", node.skin
    assert node.update_attributes(:parent_id => nodes_id(:people) )
    assert_equal groups_id(:workers), node.rgroup_id
    assert_equal groups_id(:workers), node.wgroup_id
    assert_equal groups_id(:workers), node.pgroup_id
    assert_equal "wiki", node.skin
  end

  def test_skin_changed_children_too
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater)  }
    node[:inherit  ] = 0
    node[:skin] = 'wiki'
    assert node.save , "Save succeeds"
    assert_equal 'wiki', node[:skin], "Template changed"
    assert_equal 'wiki', nodes(:status    ).skin, "Child skin changed"
    assert_equal 'wiki', nodes(:water_pdf ).skin, "Child skin changed"
    assert_equal 'wiki', nodes(:lake_jpg  ).skin, "Grandchild skin changed"
    assert_equal 'default', nodes(:bananas).skin, "Not inherited child: skin not changed"
  end

  def test_skin_change_root_node
    login(:tiger)
    node = secure!(Node) { nodes(:zena)  }
    Node.connection.execute "UPDATE nodes SET inherit = 0 WHERE id = '#{nodes_id(:cleanWater)}'"
    node[:skin] = 'wiki'
    assert node.save , "Save succeeds"
    assert_equal 'wiki', node[:skin], "Template changed"
    assert_equal 'wiki', nodes(:people).skin, "Child skin changed"
    assert_equal 'wiki', nodes(:projects).skin, "Child skin changed"
    assert_equal 'wiki', nodes(:lion).skin, "Grandchild skin changed"
    assert_equal 'default', nodes(:status).skin, "Not inherited child: skin not changed"
  end

  # 2. if owner changed from old, make sure only a user in 'admin' can do this
  def test_owner_changed_visitor_not_admin
    # not in 'admin' group
    login(:tiger)
    node = secure!(Node) { nodes(:bananas) }
    assert_kind_of Node, node
    assert_equal users_id(:lion), node.user_id
    node.user_id = users_id(:tiger)
    assert ! node.save , "Save fails"
    assert node.errors[:user_id].any?
    assert_equal 'only admins can change owners', node.errors[:user_id]
  end
  def test_owner_changed_bad_user
    # cannot write in new contact
    login(:lion)
    node = secure!(Node) { nodes(:bananas) }
    assert_kind_of Node, node
    assert_equal users_id(:lion), node.user_id
    node.user_id = 99
    assert ! node.save , "Save fails"
    assert node.errors[:user_id].any?
    assert_equal 'unknown user', node.errors[:user_id]
  end
  def test_owner_changed_ok
    login(:lion)
    node = secure!(Node) { nodes(:bananas) }
    node.user_id = users_id(:tiger)
    assert node.save , "Save succeeds"
    node.reload
    assert_equal users_id(:tiger), node.user_id
  end

  # 3. error if user cannot visible nor manage
  def test_cannot_visible_nor_manage
    login(:ant)
    node = secure!(Node) { nodes(:collections) }
    assert ! node.can_drive? , "Cannot visible"
    assert ! node.can_drive? , "Cannot manage"
    assert ! node.update_attributes('name' => 'no way') , "Save fails"
    assert node.errors[:base].any?
    assert_equal 'you do not have the rights to do this', node.errors[:base]
  end

  # 4. parent changed ? verify 'visible access to new *and* old'
  def test_reference_changed_cannot_pub_in_new
    login(:ant)
    # cannot visible in new ref
    node = secure!(Node) { nodes(:bird_jpg) } # can visible in reference
    node[:parent_id] = nodes_id(:cleanWater) # cannot visible here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    assert ['invalid reference'], node.errors[:parent_id]
  end
  def test_reference_changed_cannot_pub_in_old
    login(:ant)
    # cannot visible in old ref
    node = secure!(Node) { nodes(:talk)  } # cannot visible in parent 'secret'
    node[:parent_id] = nodes_id(:wiki) # can visible here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    assert ['invalid reference'], node.errors[:parent_id]
  end

  def test_reference_changed_ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) } # can visible here
    node[:parent_id] = nodes_id(:wiki) # can visible here
    assert node.save , "Save succeeds"
    assert_equal node[:project_id], nodes(:wiki)[:id], "Same project as parent"
  end

  # 5. validate +rw groups+ :
  #     a. can change to 'inherit' if can_drive?
  #     b. can change to 'private' if can_drive?
  #     c. can change to 'custom'  if can_drive?
  def test_update_rw_groups_for_publisher_bad_rgroup
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    p = secure!(Page) { Page.find(node[:parent_id])}
    assert p.can_drive? , "Can visible in reference" # can visible in reference
    assert node.can_drive? , "Can visible"

    # bad rgroup or tiger not in admin
    [99999, groups_id(:admin)].each do |grp|
      # bad rgroup
      node[:inherit  ] = 0
      node[:rgroup_id] = grp
      assert ! node.save , "Save fails"
      assert node.errors[:rgroup_id].any?
      assert_equal 'unknown group', node.errors[:rgroup_id]
    end
  end

  def test_update_rw_groups_for_publisher_not_in_new_rgroup
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    node[:inherit  ] = 0
    node[:rgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! node.save , "Save fails"
    assert node.errors[:rgroup_id].any?
    assert_equal 'unknown group', node.errors[:rgroup_id]
  end
  def test_update_rw_groups_for_publisher_bad_wgroup
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    # bad wgroup
    node[:inherit  ] = 0
    node[:wgroup_id] = 99999
    assert ! node.save , "Save fails"
    assert node.errors[:wgroup_id].any?
    assert_equal 'unknown group', node.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_not_in_new_wgroup
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    node[:inherit  ] = 0
    node[:wgroup_id] = groups_id(:admin) # tiger is not in admin
    assert ! node.save , "Save fails"
    assert node.errors[:wgroup_id].any?
    assert_equal 'unknown group', node.errors[:wgroup_id]
  end
  def test_update_rw_groups_for_publisher_ok
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    # all ok
    node[:inherit  ] = 0
    node[:rgroup_id] = groups_id(:public)
    node[:wgroup_id] = groups_id(:managers)
    assert node.save , "Save succeeds"
    assert node.errors.empty? , "Errors empty"
  end

  context 'A draft' do
    setup do
      login(:ant)
      @node, ref = create_simple_note
    end

    should 'be a draft' do
      assert @node.draft?
    end

    should 'let owner drive' do
      assert @node.can_drive?
    end

    should 'not let owner publish' do
      assert !@node.can_publish?
      assert !@node.update_attributes(:v_status => Zena::Status[:pub])
      assert_equal 'You do not have the rights to publish', @node.errors[:base]
    end

    should 'not let owner change inherit mode' do
      @node[:inherit] = 0
      assert !@node.save
      assert_equal 'you cannot change this', @node.errors[:inherit]
    end

    should 'be freely moved around by owner' do
      @node.parent_id = nodes_id(:status)
      assert @node.save
      assert_equal nodes_id(:status), @node.parent_id
    end

    should 'let owner remove version and destroy itself' do
      assert @node.can_remove?
      assert @node.remove
      assert_difference('Node.count', -1) do
        assert @node.destroy_version
      end
    end
  end

  context 'A draft with children' do
    setup do
      node_ids = [:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')
      login(:ant)
      Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:ant)} WHERE node_id IN (#{node_ids})"
      Node.connection.execute "UPDATE nodes SET publish_from = NULL WHERE id IN (#{node_ids})"
      @node = secure!(Node) { nodes(:wiki) }
    end

    should 'be freely moved around by owner' do
      @node.parent_id = nodes_id(:status)
      assert @node.save
      assert_equal nodes_id(:status), @node.parent_id
    end

    should 'not be freely moved around by owner if it contains publications' do
      Node.connection.execute "UPDATE nodes SET publish_from = '2009-9-26 20:26' WHERE id IN (#{nodes_id(:bird_jpg)})"
      @node.parent_id = nodes_id(:status)
      assert @node.send(:published_in_heirs_was_true?)
      assert !@node.save
      assert_equal 'invalid reference', @node.errors[:parent_id]
    end
  end

  def test_can_man_can_inherit
    node, ref = create_simple_note
    # inherit
    node[:inherit  ] = 1 # inherit
    assert !node.save , "Save succeeds"
    assert_equal ref.rgroup_id, node.rgroup_id ,    "Read group is same as reference"
    assert_equal ref.wgroup_id, node.wgroup_id ,   "Write group is same as reference"
    assert_equal ref.pgroup_id, node.pgroup_id , "Publish group is same as reference"
    assert_equal 1, node.inherit , "Inherit mode is 1"
  end

  def test_cannot_set_publish_from
    login(:tiger)
    node = secure!(Node) { nodes(:lake)  }
    now = Time.now
    old = node.publish_from
    node.attributes = {:publish_from => now}
    assert node.save
    assert_equal node.publish_from, old
  end

  def test_update_name_drive_group
    login(:lion) # owns 'strange'
    node = secure!(Node) { nodes(:strange)  }
    assert node.propose
    login(:ant)
    node = secure_drive(Node) { nodes(:strange)  } # only in pgroup
    node.name = "kali"
    assert node.save
  end
  #     3. removing the node and/or sub-nodes
  def test_destroy
    login(:ant)
    node = secure!(Node) { nodes(:lake)  }
    assert !node.destroy, "Cannot destroy"
    assert_equal 'you do not have the rights to do this', node.errors[:base]

    login(:tiger)
    node = secure!(Node) { nodes(:lake)  }
    assert node.destroy, "Can destroy"
  end

  def test_secure_user
    login(:ant)
    user = secure!(User) { users(:tiger) }
    assert_kind_of User, user
    assert_equal users_id(:ant), user.send(:visitor).id
  end

  def test_cannot_view_own_stuff_in_other_host
    # make 'whale' a cross site user
    User.connection.execute "INSERT INTO participations (user_id, site_id, status) VALUES (#{users_id(:whale)}, #{sites_id(:zena)}, #{User::Status[:user]})"
    User.connection.execute "INSERT INTO groups_users (user_id, group_id) VALUES (#{users_id(:whale)}, #{groups_id(:workers)})"
    User.connection.execute "INSERT INTO groups_users (user_id, group_id) VALUES (#{users_id(:whale)}, #{groups_id(:public)})"
    login(:whale, 'ocean')
    node = nil
    assert_nothing_raised{ node = secure!(Node) { nodes(:ocean) }}
    assert_kind_of Node, node
    visitor.site = sites(:zena)
    # whale is now visiting 'zena'
    assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { nodes(:ocean) }}
  end

  def test_secure_whatever
    login(:ant)
    # test to if a 'secure scope' can return anything
    hash = nil
    assert_nothing_raised(ActiveRecord::RecordNotFound) { hash = secure!(Node) { Hash[:a, 'a', :b, 'b'] } }
    assert_kind_of Hash, hash
    assert_equal 'a', hash[:a]
  end


  def test_clean_options
    assert_equal Hash[:conditions => ['id = ?', 3], :order => 'name ASC'], Node.clean_options(:conditions => ['id = ?', 3], :funky => 'bad', :order => 'name ASC', :from => 'users')
  end
end


class SecureVisitorStatusTest < Zena::Unit::TestCase

  def test_admin_can_write_if_in_write_group
    login(:whale)
    assert_equal visitor.status, User::Status[:admin]
    node = secure!(Node) { nodes(:ocean) }
    assert visitor.group_ids.include?(node.wgroup_id)
    assert node.can_write?
  end

  def test_reader_can_write_if_in_write_group
    login(:messy)
    assert_equal visitor.status, User::Status[:reader]
    node = secure!(Node) { nodes(:ocean) }
    assert visitor.group_ids.include?(node.wgroup_id)
    assert node.can_write?

    # Participation.connection.execute "UPDATE participations SET status = #{User::Status[:user]} WHERE user_id = #{users_id(:messy)} AND site_id = #{sites_id(:ocean)}"
    # login(:messy)
    # assert_equal visitor.status, User::Status[:user]
    # node = secure!(Node) { nodes(:ocean) }
    # assert node.can_write?, "Can write if user."
  end


  def test_reader_can_update_attributes_if_in_write_group
    login(:messy)
    assert_equal visitor.status, User::Status[:reader]
    node = secure!(Node) { nodes(:ocean) }
    assert visitor.group_ids.include?(node.wgroup_id)
    assert node.update_attributes(:v_title => 'hooba')
    assert_equal 'hooba', node.v_title
    # Participation.connection.execute "UPDATE participations SET status = #{User::Status[:user]} WHERE user_id = #{users_id(:messy)} AND site_id = #{sites_id(:ocean)}"
    # login(:messy)
    # assert_equal visitor.status, User::Status[:user]
    # node = secure!(Node) { nodes(:ocean) }
    # assert node.update_attributes(:v_title => 'hooba')
    # node.publish
  end


  def test_deleted_cannot_login
    Participation.connection.execute "UPDATE participations SET status = #{User::Status[:deleted]} WHERE user_id = #{users_id(:messy)} AND site_id = #{sites_id(:ocean)}"
    login(:messy)
    assert_equal users(:incognito)[:id], visitor.id
  end
end