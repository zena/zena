require 'test_helper'

class VirtualClassesControllerTest < Zena::Controller::TestCase

  context 'A logged in user' do

    context 'that is not an admin' do
      setup do
        login(:tiger)
      end

      context 'accessing index' do
        subject do
          {:action => :index}
        end

        should 'not be allowed' do
          get_subject
          assert_response :missing
        end
      end # accessing index
    end # that is not an admin

    context 'that is an admin' do
      setup do
        login(:lion)
      end

      context 'accessing index' do
        subject do
          {:action => :index}
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end

        should 'display list of virtual classes' do
          get_subject
          assert assigns(:virtual_classes)
        end
      end # accessing index

      should 'access new' do
        get :new
        assert_response :success
      end

      context 'creating a virtual class' do
        subject do
          {:action => :create, :virtual_class => { :name => 'Xkcd', :superclass => 'Section', :create_group_id => groups_id(:public) }}
        end

        should 'create a new VirtualClass' do
          assert_difference('VirtualClass.count', 1) do
            post_subject
          end
        end

        should 'set name, superclass and kpath' do
          post_subject
          vclass = assigns(:virtual_class)
          assert_equal 'Xkcd',  vclass.name
          assert_equal Section, vclass.superclass
          assert_equal 'NPSX',  vclass.kpath
        end

        should 'redirect to show' do
          post_subject
          assert_redirected_to virtual_class_path(assigns(:virtual_class))
        end

      end # creating a virtual class

      context 'creating a role' do
        subject do
          {:action => :create, :virtual_class => { :type => 'Role', :name => 'Xkcd', :superclass => 'Section', :create_group_id => groups_id(:public) }}
        end

        should 'create a new Role' do
          assert_difference('VirtualClass.count', 0) do
            assert_difference('Role.count', 1) do
              post_subject
            end
          end
        end

        should 'set name, superclass and kpath' do
          post_subject
          vclass = assigns(:virtual_class)
          assert_equal 'Xkcd',  vclass.name
          assert_equal Section, vclass.superclass
          assert_equal 'NPS',  vclass.kpath
        end

        should 'redirect to show' do
          post_subject
          assert_redirected_to virtual_class_path(assigns(:virtual_class))
        end

      end # creating a role

      context 'displaying a virtual class' do
        subject do
          {:action => :show, :id => roles_id(:Letter)}
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # displaying a virtual class

      context 'editing a virtual class' do
        subject do
          {:action => :edit, :id => roles_id(:Letter)}
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # editing a virtual class

      context 'updating a virtual class' do
        subject do
          {:action => :update, :id => roles_id(:Letter), :virtual_class => { :name => 'Life'}}
        end

        should 'redirect to show' do
          put_subject
          assert_redirected_to virtual_class_path(assigns(:virtual_class))
        end

        should 'save name and kpath' do
          put_subject
          vclass = assigns(:virtual_class)
          assert_equal 'Life', vclass.name
          assert_equal 'NNL',  vclass.kpath
        end

        # TODO: What happens to properties for a class if kpath changes ?
      end # updating a virtual class

      context 'updating a role' do
        subject do
          {:action => :update, :id => roles_id(:Original), :virtual_class => { :name => 'Life', :superclass => 'Post'}}
        end

        should 'redirect to show' do
          put_subject
          assert_redirected_to virtual_class_path(assigns(:virtual_class))
        end

        should 'save name and kpath' do
          put_subject
          vclass = assigns(:virtual_class)
          assert_equal 'Life', vclass.name
          assert_equal 'NNP',  vclass.kpath
        end

        # TODO: What happens to properties for a class if kpath changes ?
      end # updating a virtual class

      context 'destroying a virtual class' do
        subject do
          {:action => :destroy, :id => roles_id(:Letter)}
        end

        should 'destroy' do
          assert_difference('VirtualClass.count', -1) do
            delete_subject
          end
        end

        should 'redirect to index' do
          delete_subject
          assert_redirected_to virtual_classes_path
        end
      end # destroying a virtual class

      context 'importing virtual class definitions' do
        subject do
          {:action => :import, :attachment => uploaded_fixture('vclasses.yml', 'text/yaml')}
        end

        should 'create virtual classes' do
          assert_difference('VirtualClass.count', 3) do
            post_subject
          end
        end
      end # importing virtual class definitions
    end # that is an admin
  end # A logged in user
end