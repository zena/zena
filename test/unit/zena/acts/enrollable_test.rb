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
      end # without roles loaded
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

        context 'with roles loaded' do
          setup do
            subject.load_roles!
          end

          should 'consider role methods as safe' do
            assert_equal Hash[:class=>String, :method=>"prop['paper']", :nil=>true], subject.safe_method_type(['paper'])
          end
        end # with roles loaded

        context 'without roles loaded' do
          should 'not consider role methods as safe' do
            assert_equal nil, subject.safe_method_type(['paper'])
          end
        end # without roles loaded

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

          should 'respond to zafu_roles' do
            assert_equal %w{Original}, subject.zafu_roles.map(&:name)
          end

          should 'use cached_role_ids in zafu_roles' do
            Role.connection.execute("DELETE FROM nodes_roles")
            assert_equal %w{Original}, subject.zafu_roles.map(&:name)
          end

          context 'with new property index defined in role' do
            setup do
              column = secure(Column) { columns(:Letter_paper) }
              column.update_attributes(:index => 'string')
            end

            subject do
              secure(Node) { nodes(:letter) }
            end

            should 'rebuild property index on rebuild_index' do
              # Make sure that load_roles! is called before index rebuild
              assert_difference('IdxNodesString.count', 1) do
                subject.rebuild_index!
              end
            end
          end # with new property index defined in role
        end # with roles assigned

        should 'not allow arbitrary attributes' do
          assert !subject.update_attributes('assigned' => 'flat Eric', 'bad' => 'property')
        end

        should 'not raise on bad attributes' do
          assert_nothing_raised do
            subject.attributes = {'elements' => 'Statistical Learning'}
          end
        end

        should 'add an error on first bad attributes' do
          subject.attributes = {'elements' => 'Statistical Learning'}
          assert !subject.save
          assert_equal 'unknown attribute', subject.errors[:elements]
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

        should 'respond to zafu_possible_roles' do
          assert_equal %w{Original Task Letter}, subject.zafu_possible_roles.map {|r| r.name}
        end
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

    context 'A safe method returning a sub-class of Node' do
      subject do
        ['section']
      end

      should 'return a fully loaded class on safe_method_type' do
        type = Node.safe_method_type(subject)
        assert type[:class] < Section
        assert_equal %w{assigned cached_role_ids origin summary text title tz weight}, type[:class].schema.columns.keys.sort
      end
    end # A safe method returning a sub-class of Node

    context 'A class with a safe_node_context to a virtual class' do
      subject do
        Class.new(Page) do
          safe_node_context :foo => :Post
        end
      end

      should 'properly resolve type' do
        type = subject.safe_method_type(['foo'])
        assert_equal type[:class].kpath, roles(:Post).kpath
      end
    end # A class with a safe_node_context to a virtual class
  end # A visitor with write access

  context 'A class with Named included' do
    subject do
      Class.new(Node) do
        include Zena::Acts::Enrollable::Named
      end.tap do |c|
        c.to_s  = 'Papa'
        c.kpath = 'NRC'
      end
    end

    should 'return name on to_s' do
      assert_equal 'Papa', subject.to_s
    end

    should 'load roles including _name_ in instance' do
      # This used to break on 'name' property defined somewhere in a superclass
      assert_nothing_raised { subject.new }
    end

    # This is because we include a module and the module would hide the method
    should 'be allowed to define a _name_ property' do
      assert_nothing_raised do
        subject.class_eval do
          property.string 'name'
        end
      end
    end
  end # A class with Named included

end
