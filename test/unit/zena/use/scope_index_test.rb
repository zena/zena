require 'test_helper'

class ScopeIndexTest < Zena::Unit::TestCase
  context 'Creating a scope indexed project' do
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
        secure(Node) { Node.create_node(:klass => 'Post', :title => 'Knock Knock', :origin => 'Friendly ghosts', :parent_id => @project.zip)}
      end

      should 'not update project index' do
        assert_difference('IdxProject.count', 0) do
          subject
          assert_equal 'foobar', IdxProject.find(@project.scope_index).NNP_origin
        end
      end
    end # inserting a sub node

    context 'creating a sub node' do
      subject do
        secure(Node) { Node.create_node(:klass => 'Post', :title => 'Knock Knock', :origin => 'Friendly ghosts', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      should 'update project index' do
        assert_difference('IdxProject.count', 0) do
          subject
          assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NNP_origin
          assert_equal 'Knock Knock', IdxProject.find(@project.scope_index).NNP_title
        end
      end

      should 'set group key id' do
        assert_equal subject.id, IdxProject.find(@project.scope_index).NNP_id
      end

      should 'not update elements not matching kpath' do
        subject
        assert_nil IdxProject.find(@project.scope_index).NP_created_at
      end
    end # creating a sub node

    context 'updating a sub node' do
      setup do
        @old_post = secure(Node) { Node.create_node(:klass => 'Post', :title => 'Tadam', :origin => 'Africa', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
        @post = secure(Node) { Node.create_node(:klass => 'Post', :title => 'Knock Knock', :origin => 'Friendly ghosts', :parent_id => @project.zip, :v_status => Zena::Status[:pub])}
      end

      subject do
        @post
      end

      should 'update project index' do
        subject.update_attributes(:origin => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).NNP_origin
      end

      should 'keep group key id' do
        subject.update_attributes(:origin => 'Mean ghosts', :v_status => Zena::Status[:pub])
        assert_equal @post.id, IdxProject.find(@project.scope_index).NNP_id
      end

      should 'not update project index if not published' do
        subject.update_attributes(:origin => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NNP_origin
      end
      
      should 'update project index if on publish' do
        subject.update_attributes(:origin => 'Mean ghosts')
        assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NNP_origin
        subject.publish
        assert_equal 'Mean ghosts', IdxProject.find(@project.scope_index).NNP_origin
      end

      context 'that is not the latest of its kind' do
        subject do
          @old_post
        end

        should 'not update project index' do
          subject.update_attributes(:origin => 'China', :v_status => Zena::Status[:pub])
          assert_equal 'Friendly ghosts', IdxProject.find(@project.scope_index).NNP_origin
        end

        should 'not change group id' do
          subject.update_attributes(:origin => 'China', :v_status => Zena::Status[:pub])
          assert_equal @post.id, IdxProject.find(@project.scope_index).NNP_id
        end
      end # that is not the latest of its kind

    end # updating a sub node

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
      assert_equal Hash['NN' => %w{id log_at}, 'NP' => %w{id created_at}, 'NPP' => %w{id title}, 'NNP' => %w{id origin title}], subject.groups
    end
  end # With an index model

  context 'Using RubyLess with an indexed model' do
    subject do
      Zena::Acts::Enrollable.make_class(roles(:Blog))
    end

    should 'return model class' do
      code = RubyLess.translate(subject, 'scope_index')
      assert_equal 'scope_index', code.to_s
      assert_equal IdxProject, code.klass
    end
  end # Using RubyLess with an indexed model


  context 'Using RubyLess without an indexed model' do
    subject do
      Zena::Acts::Enrollable.make_class(Project)
    end

    should 'raise an error' do
      assert_raise(::RubyLess::Error) do
        RubyLess.translate(subject, 'scope_index')
      end
    end
  end # Using RubyLess with an indexed model

  context 'Using RubyLess not on a Project or Section' do
    subject do
      Zena::Acts::Enrollable.make_class(Page)
    end

    should 'raise an error' do
      assert_raise(::RubyLess::Error) do
        RubyLess.translate(subject, 'scope_index')
      end
    end
  end # Using RubyLess with an indexed model
end