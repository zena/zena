require 'test_helper'

class EnrollableTest < Zena::Unit::TestCase

  class NodesRoles < ActiveRecord::Base
    set_table_name :nodes_roles
  end

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a node' do
      context 'from a class with roles' do
        subject do
          secure(Node) { nodes(:letter) }
        end

        should 'add role on property set' do
          assert_difference('NodesRoles.count', 1) do
            assert subject.update_attributes('properties' => {'assigned' => 'flat Eric'})
            assert_equal 'flat Eric', subject.assigned
            assert_equal [roles_id(:Task)], subject.cached_role_ids
          end
        end

        context 'with new property index defined' do
          setup do
            column = secure(Column) { columns(:Letter_paper) }
            column.update_attributes(:index => 'string')
          end

          should 'rebuild property index on rebuild_index' do
            assert_difference('IdxNodesString.count', 1) do
              # New key = paper
              subject.rebuild_index!
            end
            
            indices = Hash[*IdxNodesString.find(:all, :conditions => {:node_id => subject.id}).map {|r| [r.key, r.value]}.flatten]
            assert_equal Hash[
              'search_mono'=>'Kraft mono',
              'paper'=>'Kraft'], indices
          end
        end # with new property index defined in role

        should 'respond to zafu_possible_roles' do
          assert_equal %w{Original Task}, subject.zafu_possible_roles.map {|r| r.name}
        end

        context 'with roles assigned' do
          subject do
            secure(Node) { nodes(:tree_jpg) }
          end

          should 'not remove role until last prop is blank' do
            assert_difference('NodesRoles.count', 0) do
              assert subject.update_attributes('origin' => '')
            end
          end

          should 'remove role when all prop are blank' do
            assert_difference('NodesRoles.count', -1) do
              assert subject.update_attributes('origin' => '', 'tz' => '')
              assert_nil subject.origin
              assert_nil subject.cached_role_ids
            end
          end

          should 'delete nodes_roles on destroy' do
            preserving_files('test.host/data') do
              assert_difference('NodesRoles.count', -1) do
                subject.destroy
              end
            end
          end

          should 'rebuild nodes_roles index on publish' do
            # make sure we are creating all versions in the same lang
            visitor.lang = subject.version.lang

            # 1. publish current version
            assert_difference('NodesRoles.count', 0) do
              subject.publish
            end

            orig_version_id = subject.version.id

            # 2. create a new version and publish
            assert_difference('NodesRoles.count', -1) do
              subject.update_attributes('origin' => '', 'tz' => '')
              assert subject.publish
            end

            # make sure properties are reloaded
            subject = secure(Node) { nodes(:nature) }
            subject.version = Version.find(orig_version_id)

            # 3. publish old version should rebuild index
            assert_difference('NodesRoles.count', 1) do
              assert subject.publish
            end
          end

          should 'respond to assigned_roles' do
            assert_equal %w{Original}, subject.assigned_roles.map(&:name)
          end

          should 'use cached_role_ids in assigned_roles' do
            Role.connection.execute("DELETE FROM nodes_roles")
            assert_equal %w{Original}, subject.assigned_roles.map(&:name)
          end
          
          context 'with bad cached_ids' do
            setup do
              node = secure(Node) { nodes(:tree_jpg) }
              node.prop['cached_role_ids'] = [1,2,3]
              Zena::Db.execute "UPDATE #{Version.table_name} SET properties=#{Zena::Db.quote(Version.encode_properties(node.prop))} WHERE id=#{node.version.id}"
            end

            should 'rebuild cached_role_ids on rebuild_index' do
              subject.rebuild_index!
              node = secure(Node) { nodes(:tree_jpg) }
              assert_equal [roles_id(:Original)], node.prop['cached_role_ids']
            end
          end # with bad cached_ids
        end # with roles assigned

      end # from a class with roles
    end # on a node

    context 'A safe method returning a sub-class of Node' do
      subject do
        ['section']
      end

      should 'return a Proc on safe_method_type' do
        type = Node.safe_method_type(subject)
        assert_kind_of Proc, type[:class]
        klass = type[:class].call[:class]
        assert_equal VirtualClass['Section'], klass
        assert_equal %w{assigned cached_role_ids origin summary text title tz weight}, klass.columns.keys.sort
      end
    end # A safe method returning a sub-class of Node

    context 'A class with a safe_node_context to a virtual class' do
      subject do
        Class.new(Page) do
          safe_node_context :foo => 'Post'
        end
      end

      should 'properly resolve type' do
        type = subject.safe_method_type(['foo'])
        assert_equal VirtualClass['Post'], type[:class].call[:class]
      end
    end # A class with a safe_node_context to a virtual class
  end # A visitor with write access
end
