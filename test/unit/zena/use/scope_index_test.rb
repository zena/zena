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
      assert_equal 'NewThoughts', index.blog_title
      assert_equal subject.id, index.blog_id
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
          assert_nil IdxProject.find(@project.scope_index).tag_created_at
        end
      end
    end # inserting a sub node

    context 'creating a sub node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Contact', :name => 'Gods', :first_name => 'Young', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update project index through relation' do
        assert_difference('IdxProject.count', 0) do
          subject
          idx = IdxProject.find(@project.scope_index)
          assert_equal 'Young',    idx.contact_first_name
          assert_equal 'Gods',     idx.contact_name
        end
      end
      
      should 'not update other relations' do
        assert_difference('IdxProject.count', 0) do
          subject
          idx = IdxProject.find(@project.scope_index)
          assert_equal 'ref',      idx.reference_name
          assert_nil               idx.reference_title
          assert_nil               idx.reference_id
        end
      end

      should 'set group key id' do
        assert_equal subject.id, IdxProject.find(@project.scope_index).contact_id
      end
    end # creating a sub node

    context 'updating a sub node' do
      setup do
        @old_tag = secure(Node) { Node.create_node(:klass => 'Contact', :title => 'Tadam', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
        @tag = secure(Node) { Node.create_node(:klass => 'Tag', :title => 'Friendly ghosts', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      subject do
        @tag
      end

      should 'update project index through relation' do
        subject.update_attributes(:title => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).tag_title
      end

      should 'keep group key id' do
        subject.update_attributes(:title => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal @tag.id, IdxProject.find(@project.scope_index).tag_id
      end

      should 'not update project index if not published' do
        subject.update_attributes(:title => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).tag_title
      end

      should 'update project index on publish' do
        subject.update_attributes(:title => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).tag_title
        subject.publish
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).tag_title
      end

      context 'that is not the latest of its kind' do
        subject do
          @old_tag
        end

        should 'not update project index' do
          subject.update_attributes(:title => 'China', :v_status => Zena::Status[:pub])
          assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).tag_title
        end

        should 'not change group id' do
          subject.update_attributes(:title => 'China', :v_status => Zena::Status[:pub])
          assert_equal @tag.id, IdxProject.find(@project.scope_index).tag_id
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
          idx = IdxProject.find(@project.scope_index)
          assert_equal 'Gods',       idx.reference_name
          assert_equal 'Young Gods', idx.reference_title
        end
      end
      
      should 'not update other relations' do
        assert_difference('IdxProject.count', 0) do
          subject
          idx = IdxProject.find(@project.scope_index)
          assert_nil                 idx.contact_first_name
          assert_equal 'cont',       idx.contact_name
          assert_nil                 idx.contact_id
        end
      end

      should 'set group key id' do
        assert_equal subject.id, IdxProject.find(@project.scope_index).reference_id
      end
    end # creating a related node

    context 'updating a related node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Contact', :name => 'Gods', :first_name => 'Young', :parent_id => nodes_zip(:zena), :reference_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update all entries in related index' do
        assert_difference('IdxProject.count', 0) do
          subject.update_attributes(:first_name => 'Old', :v_status => Zena::Status[:pub])
          assert_equal 'Old Gods', IdxProject.find(@project.scope_index).reference_title
          assert_equal 'Gods', IdxProject.find(@project.scope_index).reference_name
        end
      end

      context 'without publishing' do
        should 'not update related index' do
          assert_difference('IdxProject.count', 0) do
            subject.update_attributes(:first_name => 'Old')
            assert_equal 'Young Gods', IdxProject.find(@project.scope_index).reference_title
          end
        end
      end # without publishing
      
      context 'without all attributes' do
        subject do
          secure(Node) { Node.create_node(:klass => 'Reference', :title => 'Burn these tests', :parent_id => nodes_zip(:zena), :reference_id => @project.zip, :v_status => Zena::Status[:pub])}
        end

        should 'update related index' do
          assert_difference('IdxProject.count', 0) do
            assert subject.update_attributes(:title => 'Ashes', :v_status => Zena::Status[:pub])
            assert_equal 'Ashes', IdxProject.find(@project.scope_index).reference_title
            assert_equal 'ref', IdxProject.find(@project.scope_index).reference_name
          end
        end
      end # without all attributes
      
    end # updating a related node

    context 'updating the project' do
      subject do
        @project
      end

      should 'update index' do
        subject.update_attributes(:title => 'Wacky', :v_status => Zena::Status[:pub])
        assert_equal 'Wacky', IdxProject.find(@project.scope_index).blog_title
      end
    end # updating the project
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
      assert_equal Hash['reference' => %w{id name title}, 'blog' => %w{id title}, 'tag' => %w{id created_at title}, 'contact' => %w{id first_name name}], subject.groups
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
      code = RubyLess.translate(subject, 'scope_index.tag_title')
      assert_equal '(scope_index ? scope_index.tag_title : nil)', code.to_s
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
        {:name => 'Song', :superclass => 'Post', :idx_scope => "{'reference' => 'project'}", :create_group_id => groups_id(:public) }
      end

      should 'create' do
        assert_difference('VirtualClass.count', 1) do
          VirtualClass.create(subject)
        end
      end
    end # with a valid idx_scope

    context 'with an invalid idx_scope' do
      subject do
        {:name => 'Song', :superclass => 'Post', :idx_scope => "{1 => 'project'}", :create_group_id => groups_id(:public) }
      end

      should 'not create' do
        assert_difference('VirtualClass.count', 0) do
          VirtualClass.create(subject)
        end
      end

      should 'add errors to idx_scope' do
        vclass = VirtualClass.create(subject)
        assert_equal "Invalid entry: keys and query should be of type String (1 => \"project\")", vclass.errors[:idx_scope]
      end
    end # with an invalid idx_scope
    
    context 'with an invalid idx_scope type' do
      subject do
        {:name => 'Song', :superclass => 'Post', :idx_scope => "project", :create_group_id => groups_id(:public) }
      end

      should 'not create' do
        assert_difference('VirtualClass.count', 0) do
          VirtualClass.create(subject)
        end
      end

      should 'add errors to idx_scope' do
        vclass = VirtualClass.create(subject)
        assert_equal "Invalid type: should be a hash.", vclass.errors[:idx_scope]
      end
    end # with an invalid idx_scope type
    
    context 'with an invalid query in idx_scope' do
      subject do
        {:name => 'Song', :superclass => 'Post', :idx_scope => "{'reference' => 'project where foo is null'}", :create_group_id => groups_id(:public) }
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
    end # with an invalid query in idx_scope
  end # Creating a virtual class
  
end