require 'test_helper'

class ScopeIndexTest < Zena::Unit::TestCase
  context 'Creating a scope indexed blog' do
    setup do
      login(:lion)
    end

    subject do
      secure(Node) { Node.create_node(:title => 'NewThoughts', :klass => 'Blog', :parent_id => nodes_zip(:zena), :v_status => Zena::Status[:pub]) }
    end

    should 'create' do
      assert !subject.new_record?
    end

    should 'create index entry with values from project' do
      assert_difference('IdxProject.count', 1) do
        subject
      end
    end

    should 'insert entries related to project' do
      subject
      index = subject.scope_index
      assert_equal 'NewThoughts', index.NPP_title
    end
  end # Creating a scope indexed project

  context 'In an indexed project' do
    setup do
      login(:lion)
      @project = secure(Node) { nodes(:wiki) }
    end

    context 'inserting a sub node without publishing' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Tag', :title => 'Knock Knock', :parent_id => @project.zip)}
      end

      should 'not update project index' do
        assert_difference('IdxProject.count', 0) do
          subject
          assert_nil IdxProject.find(@project.scope_index).NPT_created_at
        end
      end
    end # inserting a sub node

    context 'creating a sub node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Tag', :title => 'Knock Knock', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update project index' do
        assert_difference('IdxProject.count', 0) do
          subject
          assert_equal subject.title, IdxProject.find(@project.scope_index).NPT_title
          assert_equal subject.created_at.to_s, IdxProject.find(@project.scope_index).NPT_created_at.to_s
        end
      end

      should 'set group key id' do
        assert_equal subject.id, IdxProject.find(@project.scope_index).NPT_id
      end

      should 'not update elements not matching kpath' do
        subject
        assert_equal 'a wiki with Zena', IdxProject.find(@project.scope_index).NPP_title
      end
    end # creating a sub node

    context 'updating a sub node' do
      setup do
        @old_tag = secure(Node) { Node.create_node(:klass => 'Tag', :title => 'Tadam', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
        @tag = secure(Node) { Node.create_node(:klass => 'Tag', :title => 'Friendly ghosts', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      subject do
        @tag
      end

      should 'update project index' do
        subject.update_attributes(:title => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).NPT_title
      end

      should 'keep group key id' do
        subject.update_attributes(:title => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal @tag.id, IdxProject.find(@project.scope_index).NPT_id
      end

      should 'not update project index if not published' do
        subject.update_attributes(:title => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NPT_title
      end

      should 'update project index on publish' do
        subject.update_attributes(:title => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NPT_title
        subject.publish
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).NPT_title
      end

      context 'that is not the latest of its kind' do
        subject do
          @old_tag
        end

        should 'not update project index' do
          subject.update_attributes(:title => 'China', :v_status => Zena::Status[:pub])
          assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NPT_title
        end

        should 'not change group id' do
          subject.update_attributes(:title => 'China', :v_status => Zena::Status[:pub])
          assert_equal @tag.id, IdxProject.find(@project.scope_index).NPT_id
        end
      end # that is not the latest of its kind

    end # updating a sub node

    context 'creating a related node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Contact', :name => 'Gods', :first_name => 'Young', :parent_id => nodes_zip(:zena), :reference_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update related index' do
        assert_difference('IdxProject.count', 0) do
          subject
          assert_equal subject.name, IdxProject.find(@project.scope_index).NRC_name
          assert_equal subject.first_name, IdxProject.find(@project.scope_index).NRC_first_name
        end
      end

      should 'set group key id' do
        assert_equal subject.id, IdxProject.find(@project.scope_index).NRC_id
      end
    end # creating a related node

    context 'updating a related node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Contact', :name => 'Gods', :first_name => 'Young', :parent_id => nodes_zip(:zena), :reference_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update related index' do
        assert_difference('IdxProject.count', 0) do
          subject.update_attributes(:first_name => 'Old', :v_status => Zena::Status[:pub])
          assert_equal 'Old', IdxProject.find(@project.scope_index).NRC_first_name
        end
      end

      context 'without publishing' do
        should 'not update related index' do
          assert_difference('IdxProject.count', 0) do
            subject.update_attributes(:first_name => 'Old')
            assert_equal 'Young', IdxProject.find(@project.scope_index).NRC_first_name
          end
        end
      end # without publishing
    end # updating a related node

    context 'updating the project' do
      subject do
        @project
      end

      should 'update index' do
        subject.update_attributes(:title => 'Wacky', :v_status => Zena::Status[:pub])
        assert_equal 'Wacky', IdxProject.find(@project.scope_index).NPP_title
      end
    end # updating the project

    should 'return idx model on scope_index' do
      assert_equal IdxProject, @project.scope_index.class
    end
  end # In an indexed project

  context 'In a non-indexed project' do
    setup do
      login(:lion)
    end

    subject do
      secure(Node) { nodes(:cleanWater) }
    end

    should 'return nil on scope_index' do
      assert_nil subject.scope_index
    end
  end # In a non-indexed project

  context 'With an index class' do
    subject do
      IdxProject
    end

    should 'build key groups' do
      assert_equal Hash['NPP' => %w{id title}, 'NPT' => %w{id created_at title}, 'NRC' => %w{id first_name name}], subject.groups
    end
  end # With an index model

  context 'Using RubyLess with an indexed model' do
    subject do
      VirtualClass['Blog']
    end

    should 'return model class on scope_index' do
      code = RubyLess.translate(subject, 'scope_index')
      assert_equal 'scope_index', code.to_s
      assert_equal IdxProject, code.klass
    end

    should 'allow index access on scope_index object' do
      code = RubyLess.translate(subject, 'scope_index.NPT_title')
      assert_equal '(scope_index ? scope_index.NPT_title : nil)', code.to_s
      assert_equal String, code.klass
    end
  end # Using RubyLess with an indexed model

  context 'Using RubyLess without an indexed model' do
    subject do
      VirtualClass['Project']
    end

    should 'raise an error' do
      assert_raise(::RubyLess::NoMethodError) do
        RubyLess.translate(subject, 'scope_index')
      end
    end
  end # Using RubyLess with an indexed model

  context 'Using RubyLess not on a Project or Section' do
    subject do
      VirtualClass['Page']
    end

    should 'raise an error' do
      assert_raise(::RubyLess::NoMethodError) do
        RubyLess.translate(subject, 'scope_index')
      end
    end
  end # Using RubyLess with an indexed model

  context 'Creating a virtual class' do
    setup do
      login(:lion)
    end

    context 'with a valid idx_class' do
      subject do
        {:name => 'Concert', :superclass => 'Project', :idx_class => 'IdxProject', :create_group_id => groups_id(:public) }
      end

      should 'create' do
        assert_difference('VirtualClass.count', 1) do
          VirtualClass.create(subject)
        end
      end
    end # with a valid idx_class

    context 'with an invalid idx_class' do
      subject do
        {:name => 'Concert', :superclass => 'Project', :idx_class => 'Page', :create_group_id => groups_id(:public) }
      end

      should 'not create' do
        assert_difference('VirtualClass.count', 0) do
          VirtualClass.create(subject)
        end
      end

      should 'add errors to idx_class' do
        vclass = VirtualClass.create(subject)
        assert_equal 'invalid class (should include ScopeIndex::IndexMethods)', vclass.errors[:idx_class]
      end

      should 'not evaluate bad idx_class' do
        vclass = VirtualClass.create(subject.merge(:idx_class => 'puts "BAD!"'))
        assert_equal 'invalid class name', vclass.errors[:idx_class]
      end
    end # with an invalid idx_class


    context 'with a valid idx_scope' do
      subject do
        {:name => 'Song', :superclass => 'Post', :idx_scope => 'project', :create_group_id => groups_id(:public) }
      end

      should 'create' do
        assert_difference('VirtualClass.count', 1) do
          VirtualClass.create(subject)
        end
      end
    end # with a valid idx_scope

    context 'with an invalid idx_scope' do
      subject do
        {:name => 'Song', :superclass => 'Post', :idx_scope => 'project where foo is null', :create_group_id => groups_id(:public) }
      end

      should 'not create' do
        assert_difference('VirtualClass.count', 0) do
          VirtualClass.create(subject)
        end
      end

      should 'add errors to idx_scope' do
        vclass = VirtualClass.create(subject)
        assert_equal "Invalid query: Unknown field 'foo'.", vclass.errors[:idx_scope]
      end
    end # with an invalid idx_scope
  end # Creating a virtual class

end