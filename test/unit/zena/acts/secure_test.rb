require 'test_helper'

class SecureTest < Zena::Unit::TestCase

  def create_simple_note(opts={})
    login(opts[:login] || :ant)
    # create new node
    attrs =  {
      :node_name => 'hello',
      :parent_id => nodes_id(:cleanWater)
    }.merge(opts[:node] || {})

    node = secure!(Note) { Note.create(attrs) }

    ref  = secure!(Node) { Node.find_by_id(attrs[:parent_id])}

    [node, ref]
  end

  context 'A class path (kpath)' do
    should 'represent the class hierarchy' do
      assert_equal 'N', Node.kpath
      assert_equal 'NP', Page.kpath
      assert_equal 'U', PagerDummy.ksel
      assert_equal 'NU', PagerDummy.kpath
      assert_equal 'NUS', SubPagerDummy.kpath
    end
  end

  context 'A visitor' do
    setup do
      login(:anon)
    end

    context 'with a forbidden node' do
      subject do
        nodes(:secret)
      end

      should 'raise an exception when trying to find the node with secure! read scope' do
        assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { subject }}
      end

      should 'raise an exception when trying to find the node with secure! write scope' do
        assert_raise(ActiveRecord::RecordNotFound) { secure_write!(Node) { subject }}
      end

      should 'raise an exception when trying to find the node with secure! drive scope' do
        assert_raise(ActiveRecord::RecordNotFound) { secure_drive!(Node) { subject }}
      end

      should 'receive nil when calling secure read' do
        assert_nothing_raised do
          assert_nil secure(Node) { subject }
        end
      end

      should 'receive nil when calling secure write' do
        assert_nothing_raised do
          assert_nil secure_write(Node) { subject }
        end
      end

      should 'receive nil when calling secure drive' do
        assert_nothing_raised do
          assert_nil secure_drive(Node) { subject }
        end
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
        subject do
          nodes(:secret)
        end

        should 'receive false when asking can_read?' do
          assert !subject.can_read?
        end

        should 'receive false when asking can_write?' do
          assert !subject.can_write?
        end

        should 'receive false when asking can_drive?' do
          assert !subject.can_drive?
        end
      end
    end # with a forbidden node

    context 'with an accessible node' do
      subject do
        nodes(:status)
      end

      context 'loaded with secure' do
        subject do
          secure!(Node) { nodes(:status) }
        end

        should 'be valid' do
           assert subject.valid?
        end

        should 'be secured' do
          assert subject.secured?
        end
      end

      context 'loaded without secure' do
        should 'not be valid' do
          assert !subject.valid?
        end

        should 'not be secured' do
          assert !subject.secured?
        end
      end
    end # with an accessible node
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
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:managers)}, wgroup_id = #{groups_id(:workers)}, dgroup_id = #{groups_id(:managers)} WHERE id IN (#{ids})"
    end

    context 'on a node that is not published yet' do
      subject do
        secure(Node) { nodes(:crocodiles) }
      end

      should 'see it' do
        assert subject
      end

      should 'not be allowed to publish' do
        assert !subject.publish
      end

      should 'not be allowed to publish with v_status' do
        assert !subject.update_attributes(:v_status => Zena::Status[:pub])
      end
    end

    context 'on a published node' do
      subject do
        secure(Node) { nodes(:bananas) }
      end

      should 'see it' do
        assert subject
      end
    end

    context 'that is a user' do
      should 'be allowed to write redactions' do
        node = secure(Node) { nodes(:bananas) }
        assert node.can_write?
        assert node.update_attributes(:title => 'max havelaar')
        node = secure(Node) { nodes(:bananas) } # reload
        assert_equal 'max havelaar', node.title
      end
    end

    context 'that is not a user' do
      setup do
        visitor.status = User::Status[:commentator]
      end

      should 'not be allowed to write redactions' do
        node = secure(Node) { nodes(:bananas) }
        assert !node.can_write?
        assert !node.update_attributes(:title => 'max havelaar')
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
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:managers)}, wgroup_id = #{groups_id(:managers)}, dgroup_id = #{groups_id(:workers)} WHERE id IN (#{ids})"
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
      Node.connection.execute "UPDATE nodes SET rgroup_id = #{groups_id(:workers)}, wgroup_id = #{groups_id(:managers)}, dgroup_id = #{groups_id(:workers)} WHERE id IN (#{ids})"
    end

    should 'not be allowed to write' do
      node = secure!(Node) { nodes(:bananas) }
      assert !node.can_write?
      assert !node.update_attributes(:title => 'Banana republic')
      assert_equal 'You do not have the rights to edit.', node.errors[:base]
    end

    should 'not be allowed to create sub-nodes' do
      node = secure!(Node) { Node.create(defaults.merge(:parent_id => nodes_id(:bananas))) }
      assert node.new_record?
      assert_equal 'You do not have the rights to edit.', node.errors[:base]
    end

    should 'be allowed to drive' do
      node = secure!(Node) { nodes(:bananas) }
      assert node.can_drive?
      assert node.update_attributes(:node_name => 'NamWa')
    end
  end # A visitor in the read and drive groups


  def defaults
    { :node_name => 'hello',
      :parent_id => nodes_id(:zena) }
  end

  context 'A visitor in the read and write groups' do
    setup do
      login(:ant)
    end

    context 'without secure' do
      should 'not be allowed to build new children' do
        node = Node.new(defaults)
        assert_raise ActiveRecord::RecordInvalid do node.save! end
        assert_equal 'record not secured', node.errors[:base]
      end

      should 'not be allowed to create new children' do
        node = Node.create(defaults)
        assert node.new_record?
        assert_equal 'record not secured', node.errors[:base]
      end
    end

    should 'be allowed to build children nodes' do
      node = secure(Node) { Node.new(defaults) }
      assert_difference('Node.count', 1) do
        assert_difference('Version.count', 1) do
          assert node.save
        end
      end
    end

    should 'be allowed to create child nodes' do
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

    should 'be allowed to move node' do
      node = secure!(Node) { nodes(:projects) }
      node.parent_id = nodes_id(:collections)
      assert node.save
    end

    should 'not be allowed to move published node in a parent when she does not have drive rights' do
      login(:ant)
      node = secure!(Node) { nodes(:bird_jpg) }
      assert !node.update_attributes(:parent_id => nodes_id(:cleanWater))
      assert_equal 'invalid reference', node.errors[:parent_id]
    end

    should 'not be allowed to move published node out of a parent in which she does not have drive rights' do
      login(:ant)
      node = secure!(Node) { nodes(:talk) }
      assert !node.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal 'invalid reference', node.errors[:parent_id]
    end

    should 'not be allowed to set nil parent' do
      login(:ant)
      node = secure!(Node) { nodes(:talk) }
      assert !node.update_attributes(:parent_id => nil)
      assert_equal 'invalid reference', node.errors[:parent_id]
    end

    should 'not be allowed to set bad parent' do
      login(:ant)
      node = secure!(Node) { nodes(:talk) }
      assert !node.update_attributes(:parent_id => nodes_id(:secret))
      assert_equal 'invalid reference', node.errors[:parent_id]
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
      node.update_attributes(:dgroup_id => groups_id(:public))
    end

    should 'be allowed to create with custom groups' do
      node = secure!(Node) { Node.create(defaults.merge(:inherit => 0, :rgroup_id => groups_id(:managers))) }
      assert !node.new_record?
      assert_equal groups_id(:managers), node.rgroup_id
    end

    should 'be allowed to create with custom groups without setting inherit' do
      node = secure!(Node) { Node.create(defaults.merge(:rgroup_id => groups_id(:managers))) }
      assert !node.new_record?
      assert_equal groups_id(:managers), node.rgroup_id
    end

    should 'not be allowed create with bad groups' do
      node = secure!(Node) { Node.create(defaults.merge(:inherit => 0, :rgroup_id => groups_id(:admin))) }
      assert node.new_record?
      assert_equal 'unknown group', node.errors[:rgroup_id]
    end

    should 'not be allowed to create with a bad inheritance mode' do
      node = secure!(Node) { Node.create(defaults.merge(:inherit => 3, :rgroup_id => groups_id(:public))) }
      assert node.new_record?
      assert_equal 'bad inheritance mode', node.errors[:inherit]
    end

    should 'not be allowed to set a bad inheritance mode' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:inherit => 3)
      assert_equal 'bad inheritance mode', node.errors[:inherit]
    end

    should 'not be allowed to set a read group she is not in' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:inherit => 0, :rgroup_id => groups_id(:admin))
      assert_equal 'unknown group', node.errors[:rgroup_id]
    end

    should 'not be allowed to set a write group she is not in' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:inherit => 0, :wgroup_id => groups_id(:admin))
      assert_equal 'unknown group', node.errors[:wgroup_id]
    end

    should 'not be allowed to set a drive group she is not in' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:inherit => 0, :dgroup_id => groups_id(:admin))
      assert_equal 'unknown group', node.errors[:dgroup_id]
    end

    should 'not change group without explicitely changing inherit mode' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:rgroup_id => groups_id(:managers))
      assert_equal 'cannot be changed without changing inherit mode', node.errors[:rgroup_id]
    end

    should 'not be allowed to set nil on groups' do
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:rgroup_id => nil, :inherit => 0)
      assert_equal 'unknown group', node.errors[:rgroup_id]
    end

    should 'not be allowed to set publish_from' do
      node = secure!(Node) { nodes(:lake)  }
      old = node.publish_from
      assert node.update_attributes(:publish_from => Time.now)
      assert_equal old, node.publish_from
    end

    should 'be allowed to remove empty node' do
      node = secure!(Node) { nodes(:lake) }
      assert node.empty?
      assert node.destroy
    end

    should 'not be allowed to remove node with children' do
      node = secure!(Node) { nodes(:wiki)}
      assert !node.empty?
      assert !node.destroy
      assert_equal 'cannot be removed (contains subpages or data)', node.errors[:base]
    end
  end # A visitor in the drive group

  context 'A visitor not in the drive group, not on a draft' do
    setup do
      login(:ant)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'not be a draft' do
      assert !@node.draft?
    end

    should 'not be allowed to drive' do
      assert !@node.can_drive?
    end

    should 'not be allowed to change groups' do
      @node.dgroup_id = groups_id(:public)
      assert !@node.save
      assert_equal 'You do not have the rights to do this.', @node.errors[:base]
    end

    should 'not be allowed to change node_name' do
      @node.node_name = 'slitherin'
      assert !@node.save
      assert_equal 'You do not have the rights to do this.', @node.errors[:base]
    end

    should 'not be allowed to change dates' do
      @node.event_at = Time.now
      assert !@node.save
      assert_equal 'You do not have the rights to do this.', @node.errors[:base]
    end

    should 'not be allowed to destroy' do
      assert !@node.destroy
      assert_equal 'You do not have the rights to destroy.', @node.errors[:base]
    end
  end

  context 'A node readable by anonymous' do

    context 'that is not yet published' do
      setup do
        login(:ant)
        @node = secure!(Node) { nodes(:crocodiles) }
      end

      should 'not be public' do
        assert !@node.public?
      end
    end

    context 'that is published' do
      setup do
        login(:ant)
        @node = secure!(Node) { nodes(:status) }
      end

      should 'be public' do
        assert @node.public?
      end

      should 'not be public if publication date is not reached yet' do
        @node.publish_from = Time.now.advance(:days => 1)
        assert !@node.public?
      end
    end
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
      assert_equal 'You do not have the rights to publish.', @node.errors[:base]
    end

    should 'should be in inherit mode' do
      assert_equal 1, @node.inherit
    end

    should 'not let owner change inherit mode' do
      @node[:inherit] = 0
      assert !@node.save
      assert_equal 'cannot be changed', @node.errors[:inherit]
    end

    should 'not let owner change groups' do
      assert !@node.update_attributes(:rgroup_id => groups_id(:workers))
      assert_equal 'cannot be changed', @node.errors[:rgroup_id]
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
  end # A draft

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

    should 'not be freely moved around by owner if it contains deeply nested publications' do
      Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:bird_jpg)} WHERE id IN (#{nodes_id(:status)})"
      @node.parent_id = nodes_id(:status)
      assert @node.send(:published_in_heirs_was_true?)
      assert !@node.save
      assert_equal 'invalid reference', @node.errors[:parent_id]
    end
  end # A draft with children

  context 'A node with children' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:cleanWater) }
    end

    should 'update inheriting children groups on group change' do
      assert subject.update_attributes(:inherit => 0, :rgroup_id => groups_id(:workers))
      assert_equal groups_id(:workers), subject.rgroup_id
      # children
      assert_equal groups_id(:workers), nodes(:status).rgroup_id
      assert_equal groups_id(:workers), nodes(:water_pdf).rgroup_id
      # grandchildren
      assert_equal groups_id(:workers), nodes(:lake_jpg).rgroup_id
      # not inherited
      assert_equal groups_id(:managers), nodes(:bananas).rgroup_id
    end

    should 'update inheriting children groups on parent change' do
      assert subject.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal groups_id(:public), subject.rgroup_id
      # children
      assert_equal groups_id(:public), nodes(:status).rgroup_id
      assert_equal groups_id(:public), nodes(:water_pdf).rgroup_id
      # grandchildren
      assert_equal groups_id(:public), nodes(:lake_jpg).rgroup_id
      assert_equal groups_id(:public), nodes(:lake_jpg).wgroup_id
      assert_equal groups_id(:public), nodes(:lake_jpg).dgroup_id
      # not inherited
      assert_equal groups_id(:managers), nodes(:bananas).rgroup_id
    end

    should 'update inheriting children skin on skin_id change' do
      assert subject.update_attributes(:inherit => 0, :skin_id => nodes_id(:wikiSkin))
      assert_equal nodes_id(:wikiSkin), subject.skin_id
      # children
      assert_equal nodes_id(:wikiSkin), nodes(:status).skin_id
      assert_equal nodes_id(:wikiSkin), nodes(:water_pdf).skin_id
      # grandchildren
      assert_equal nodes_id(:wikiSkin), nodes(:lake_jpg).skin_id
      # not inherited
      assert_equal nodes_id(:default), nodes(:bananas).skin_id
    end

    should 'update inheriting children skin on parent change' do
      assert subject.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal nodes_id(:wikiSkin), subject.skin_id
      # children
      assert_equal nodes_id(:wikiSkin), nodes(:status).skin_id
      assert_equal nodes_id(:wikiSkin), nodes(:water_pdf).skin_id
      # grandchildren
      assert_equal nodes_id(:wikiSkin), nodes(:lake_jpg).skin_id
      # not inherited
      assert_equal nodes_id(:default), nodes(:bananas).skin_id
    end
  end # A node with children

  context 'Changing node owner' do
    should 'not be allowed if visitor is not an admin' do
      login(:tiger)
      node = secure!(Node) { nodes(:status) }
      assert !node.update_attributes(:user_id => users_id(:tiger))
      assert_equal 'Only admins can change owners', node.errors[:user_id]
    end

    context 'by an admin' do
      setup do
        login(:lion)
      end

      should 'not be allowed if new user is not valid' do
        node = secure!(Node) { nodes(:status) }
        assert !node.update_attributes(:user_id => users_id(:whale)) # not in site
        assert_equal 'unknown user', node.errors[:user_id]
      end

      should 'be allowed if new user is valid' do
        node = secure!(Node) { nodes(:status) }
        assert node.update_attributes(:user_id => users_id(:tiger)) # not in site
        assert_equal users_id(:tiger), node.user_id
      end
    end
  end # Changing node owner

  context 'Finding users' do
    setup do
      login(:ant)
    end

    context 'with secure!' do
      should 'raise an exception for users not in the same site' do
        assert_raise(ActiveRecord::RecordNotFound) { secure!(User) { users(:whale) }}
      end

      should 'be allowed for users in the same site' do
        assert user = secure!(User) { users(:tiger) }
        assert_equal users_id(:tiger), user.id
      end
    end

    context 'with secure' do
      should 'receive nil for users not in the same site' do
        node = nil
        assert_nothing_raised { node = secure(User) { users(:whale) }}
        assert_nil node
      end

      should 'be allowed for users in the same site' do
        assert user = secure(User) { users(:tiger) }
        assert_equal users_id(:tiger), user.id
      end
    end
  end # Finding users

  context 'Finding sites' do
    setup do
      login(:ant)
    end

    context 'with secure!' do
      should 'raise an exception for other sites' do
        assert_raise(ActiveRecord::RecordNotFound) { secure!(Site) { sites(:ocean) }}
      end

      should 'be allowed for current site' do
        assert site = secure!(Site) { sites(:zena) }
        assert_equal sites_id(:zena), site.id
      end
    end

    context 'with secure' do
      should 'receive nil for other sites' do
        site = nil
        assert_nothing_raised { site = secure(Site) { sites(:ocean) }}
        assert_nil site
      end

      should 'be allowed for current site' do
        assert site = secure(Site) { sites(:zena) }
        assert_equal sites_id(:zena), site.id
      end
    end
  end # Finding sites

  context 'Finding versions' do
    setup do
      login(:ant)
    end

    subject do
      # Do not let ant write in 'status' node
      Node.connection.execute "UPDATE nodes SET wgroup_id = #{groups_id(:admin)} WHERE id = #{nodes_id(:status)}"
      Version.find(:all,
        :conditions => ['versions.id IN (?)', [
          versions_id(:secret_en),
          versions_id(:status_en),
          versions_id(:strange_en_red),
          versions_id(:ant_en)]],
        :order      => 'node_name ASC')
    end

    context 'with secure' do
      should 'only return versions where visitor can read or write' do
        list = secure(Version) { subject }
        assert_equal ['Solenopsis Invicta', 'status title'], list.map {|v| v.prop['title']}
      end
    end

    context 'with secure_write' do
      should 'only return versions where visitor can write' do
        list = secure_write(Version) { subject }
        assert_equal ['Solenopsis Invicta'], list.map {|v| v.prop['title']}
      end
    end

    context 'with secure_drive' do
      should 'only return versions where visitor can drive' do
        list = secure_drive(Version) { subject }
        assert_equal ['Stranger in the night'], list.map {|v| v.prop['title']}
      end
    end
  end # Finding versions

  context 'Using secure without returning Nodes' do
    should 'not raise any exception' do
      hash = nil
      assert_nothing_raised { hash = secure!(Node) { Hash[:a, 'a', :b, 'b'] } }
      assert_kind_of Hash, hash
    end
  end # Using secure without returning Nodes

  context 'Using clean_options to prepare queries' do
    should 'remove anything that might disturb ActiveRecord' do
      assert_equal Hash[:conditions => ['id = ?', 3], :order => 'node_name ASC'], Node.clean_options(:conditions => ['id = ?', 3], :funky => 'bad', :order => 'node_name ASC', :from => 'users')
    end
  end # Using clean_options to prepare queries

  context 'A visitor with admin status' do
    setup do
      login(:lion)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'belong to all groups' do
      assert_equal secure(Group) { Group.count(:all) }, visitor.group_ids.count
    end

    should 'belong to all groups even if we remove all explicit belongings' do
      User.connection.execute "DELETE FROM groups_users WHERE user_id = #{users_id(:lion)}"
      login(:lion)
      assert_equal secure(Group) { Group.count(:all) }, visitor.group_ids.count
    end

    should 'be allowed to drive' do
      assert @node.update_attributes(:parent_id => nodes_id(:wiki))
    end

    should 'be allowed to write' do
      assert @node.update_attributes(:title => 'Drosophila')
    end
  end # A visitor with admin status

  context 'A visitor with user status' do
    setup do
      login(:tiger)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'be allowed to drive' do
      assert @node.update_attributes(:parent_id => nodes_id(:wiki))
    end

    should 'be allowed to write' do
      assert @node.update_attributes(:title => 'Drosophila')
    end

    should 'be allowed to post comments' do
      assert_difference('Comment.count', 1) do
        @node.update_attributes(:m_title => 'changed icon', :m_text => 'new icon is "flower"')
        err @node
        comment = @node.comments.last
        assert_equal 'changed icon', comment.title
        assert_equal Zena::Status[:pub], comment.status
      end
    end
  end # A visitor with user status

  context 'A visitor with commentator status' do
    setup do
      User.connection.execute "UPDATE users SET status = #{User::Status[:commentator]} WHERE id = #{users_id(:tiger)} AND site_id = #{sites_id(:zena)}"
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:status) }
    end

    should 'not be allowed to drive' do
      assert !subject.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal 'You do not have the rights to do this.', subject.errors[:base]
    end

    should 'not be allowed to write' do
      assert !subject.update_attributes(:title => 'Drosophila')
      assert_equal 'You do not have the rights to edit.', subject.errors[:base]
    end

    should 'be allowed to post comments' do
      assert_difference('Comment.count', 1) do
        assert subject.update_attributes(:m_title => 'changed icon', :m_text => 'new icon is "flower"')
        comment = subject.comments.last
        assert_equal 'changed icon', comment.title
        assert_equal Zena::Status[:pub], comment.status
      end
    end
  end # A visitor with commentator status

  context 'A visitor with moderated status' do
    setup do
      User.connection.execute "UPDATE users SET status = #{User::Status[:moderated]} WHERE id = #{users_id(:tiger)} AND site_id = #{sites_id(:zena)}"
      login(:tiger)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'be a commentator' do
      visitor.commentator?
    end

    should 'have moderated comments' do
      visitor.moderated?
    end

    should 'not be allowed to drive' do
      assert !@node.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal 'You do not have the rights to do this.', @node.errors[:base]
    end

    should 'not be allowed to write' do
      assert !@node.update_attributes(:title => 'Drosophila')
      assert_equal 'You do not have the rights to edit.', @node.errors[:base]
    end

    should 'be allowed to post moderated comments' do
      assert_difference('Comment.count', 1) do
        assert @node.update_attributes(:m_title => 'changed icon', :m_text => 'new icon is "flower"')
        comment = @node.discussion.comments(:with_prop => true).last
        assert_equal 'changed icon', comment.title
        assert_equal Zena::Status[:prop], comment.status
      end
    end
  end # A visitor with moderated status

  context 'A visitor with reader status' do
    setup do
      User.connection.execute "UPDATE users SET status = #{User::Status[:reader]} WHERE id = #{users_id(:tiger)} AND site_id = #{sites_id(:zena)}"
      login(:tiger)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'not be allowed to drive' do
      assert !@node.update_attributes(:parent_id => nodes_id(:wiki))
      assert_equal 'You do not have the rights to do this.', @node.errors[:base]
    end

    should 'not be allowed to write' do
      assert !@node.update_attributes(:title => 'Drosophila')
      assert_equal 'You do not have the rights to edit.', @node.errors[:base]
    end

    should 'not be allowed to post comments' do
      assert !@node.update_attributes(:m_title => 'changed icon', :m_text => 'new icon is "flower"')
      assert_equal 'You do not have the rights to post comments.', @node.errors[:base]
    end
  end # A visitor with reader status

  context 'Outside of an IRB session' do
    should 'not define login method' do
      assert_raise(NoMethodError) do
        Object.new.send(:login, 'lion')
      end
    end

    should 'not define secure method' do
      assert_raise(NoMethodError) do
        Object.new.send(:secure, Node)
      end
    end
  end
end