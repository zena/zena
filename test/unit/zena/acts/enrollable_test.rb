require 'test_helper'

class EnrollableTest < Zena::Unit::TestCase

  class NodesRoles < ActiveRecord::Base
    set_table_name :nodes_roles
  end

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a class' do
      subject do
        Class.new(Document)
      end

      should 'respond to load_roles!' do
        assert_nothing_raised do
          subject.load_roles!
        end
      end

      context 'with roles loaded' do
        setup do
          subject.load_roles!
        end

        should 'consider role methods as safe' do
          assert_equal Hash[:class=>String, :method=>"prop['assigned']", :nil=>true], subject.safe_method_type(['assigned'])
        end
      end # with roles loaded

      context 'without roles loaded' do

        should 'not consider role methods as safe' do
          assert_equal nil, subject.safe_method_type(['assigned'])
        end
      end # with roles loaded
    end # on a class

    context 'on a node' do
      context 'from a class with roles' do
        subject do
          secure(Node) { nodes(:letter) }
        end

        should 'raise an error before role is loaded' do
          assert_raise(NoMethodError) do
            subject.assigned = 'flat Eric'
          end
        end

        should 'load all roles on set attributes' do
          assert_nothing_raised do
            subject.attributes = {'assigned' => 'flat Eric'}
          end
        end

        should 'load all roles on set properties' do
          subject.properties = {'assigned' => 'flat Eric'}
          assert subject.save
          assert_equal 'flat Eric', subject.assigned
        end

        should 'load all roles on update_attributes' do
          assert_nothing_raised do
            assert subject.update_attributes('assigned' => 'flat Eric', 'origin' => '2D')
          end
        end

        should 'accept properties in update_attributes' do
          assert_nothing_raised do
            assert subject.update_attributes('properties' => {'assigned' => 'flat Eric'})
            assert_equal 'flat Eric', subject.assigned
          end
        end

        should 'add role on property set' do
          assert_difference('NodesRoles.count', 1) do
            assert subject.update_attributes('properties' => {'assigned' => 'flat Eric'})
            assert_equal 'flat Eric', subject.assigned
            assert_equal [roles_id(:Task)], subject.cached_role_ids
          end
        end

        context 'with roles assigned' do
          subject do
            secure(Node) { nodes(:tree_jpg) }
          end

          should 'remove role on property set to blank' do
            assert_difference('NodesRoles.count', -1) do
              assert subject.update_attributes('origin' => '')
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

          should 'rebuild index on publish' do
            # make sure we are creating all versions in the same lang
            visitor.lang = subject.version.lang

            # 1. publish current version
            assert_difference('NodesRoles.count', 0) do
              subject.publish
            end

            orig_version_id = subject.version.id

            # 2. create a new version and publish
            assert_difference('NodesRoles.count', -1) do
              subject.update_attributes('origin' => '')
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
        end # with roles assigned

        should 'not allow arbitrary attributes' do
          assert_raise(ActiveRecord::UnknownAttributeError) do
            assert subject.update_attributes('assigned' => 'flat Eric', 'bad' => 'property')
          end
        end

        should 'not allow property bypassing' do
          assert !subject.update_attributes('properties' => {'bad' => 'property'})
          assert_equal 'property not declared', subject.errors[:bad]
        end

        context 'with properties assigned through role' do
          subject do
            secure(Node) { nodes(:tree_jpg) }
          end

          should 'read attributes without loading roles' do
            assert_equal 'Big Bang', subject.prop['origin']
            assert !subject.respond_to?(:origin)
          end
        end # with properties assigned through role
      end # from a class with roles
    end # on a node

    context 'creating a node' do
      context 'with properties from roles' do
        subject do
          secure(Node) { Node.create(:parent_id => nodes_id(:zena), :title => 'foo', :origin => 'Hop')}
        end

        should 'add roles' do
          assert_difference('NodesRoles.count', 1) do
            assert_equal [roles_id(:Original)], subject.cached_role_ids
          end
        end
      end # with properties from roles

    end # creating a node

  end # A visitor with write access
end
