require 'test_helper'

class NodeNameTest < Zena::Unit::TestCase

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a node' do
      subject do
        secure!(Node) { nodes(:people) }
      end

      should 'sync node_name with title on publish' do
        assert subject.update_attributes(:title => 'nice people')
        assert subject.publish
        assert_equal 'nicePeople', subject.node_name
      end

      should 'sync node_name with title if name changed' do
        assert subject.update_attributes(:title => 'nice people', :node_name => 'foobar')
        assert_equal 'foobar', subject.node_name
        assert subject.publish
        assert_equal 'nicePeople', subject.node_name
      end

      should 'not sync node_name with title on redaction' do
        assert subject.update_attributes(:title => 'nice people')
        assert_equal 'people', subject.node_name
      end

      context 'with another node with same node_name' do
        setup do
          page = secure!(Page) { Page.create(
            :parent_id => subject.parent_id,
            :title     => 'nice people') # ==> nicePeople
          }
        end

        should 'not sync node_name with title on redaction' do
          assert subject.update_attributes(:title => 'nice people')
          assert_equal 'people', subject.node_name
        end

        should 'set an error on node_name with title on publish' do
          assert subject.update_attributes(:title => 'nice people')
          assert !subject.publish
          assert_equal subject.errors[:node_name], 'has already been taken'
        end
      end # with another node with same node_name
    end # on a node
  end # A visitor with write access

  # TODO: move these tests above

  def test_get_fullpath_rebuild
    login(:lion)
    node = secure!(Node) { nodes(:lake)  }
    assert_equal 'projects/cleanWater/lakeAddress', node.fullpath
    assert node.update_attributes(:parent_id => nodes_id(:collections))
    assert_equal 'collections/lakeAddress', node.fullpath
  end

  def test_fullpath_updated_on_parent_rename
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'people/tiger', node.fullpath
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'people/tiger', node[:fullpath] # make sure fullpath is cached

    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:title => 'nice people')
    assert node.publish
    assert_equal 'nicePeople', node.node_name # sync node_name
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'nicePeople/tiger', node[:fullpath]
  end

  def test_rootpath
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'zena/projects/cleanWater/status', node.rootpath
    node = secure!(Node) { nodes(:zena) }
    assert_equal 'zena', node.rootpath
  end

  def test_basepath
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'projects/cleanWater', node.basepath
    node = secure!(Node) { nodes(:projects) }
    assert_equal '', node.basepath
    node = secure!(Node) { nodes(:proposition) }
    assert_equal '', node.basepath
  end

  def test_sync_node_name_before_publish_if_single_version
    login(:ant)
    node = secure!(Node) { Node.create(:title => 'Eve', :parent_id => nodes_id(:people)) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal 'Eve', node.node_name
    node.update_attributes(:title => 'Lilith')
    assert_equal Zena::Status[:red], node.v_status
    assert_equal 'Lilith', node.node_name
  end

  def test_sync_node_name_on_title_change_auto_pub_no_sync
    Site.connection.execute "UPDATE sites set auto_publish = true, redit_time = 3600 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE node_id IN (#{nodes_id(:status)},#{nodes_id(:people)})"
    login(:tiger)

    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:title => 'simply different')
    assert_equal 'simplyDifferent', node.node_name
    visitor.lang = 'fr'
    # not ref lang
    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:title => 'des gens sympathiques')
    assert_equal 'fr', node.v_lang
    assert_equal 'desGensSympathiques', node.node_name
  end

  def test_sync_node_name_on_title_change_auto_pub
    test_site('zena')
    Site.connection.execute "UPDATE sites set auto_publish = true, redit_time = 3600 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE node_id IN (#{nodes_id(:people)})"
    login(:tiger)
    node = secure!(Node) { nodes(:people) }
    # was in sync, correct lang
    assert_equal node.node_name, node.title
    assert node.update_attributes(:title => 'nice people')
    node = secure!(Node) { nodes(:people) }
    assert_equal 'nice people', node.title
    assert_equal 'nicePeople', node.node_name
  end
end