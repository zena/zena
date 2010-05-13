require 'test_helper'

class ColumnsControllerTest < Zena::Controller::TestCase

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

        should 'display a list of columns' do
          get_subject
          assert assigns(:columns)
        end
      end # accessing index

      should 'access new' do
        get :new
        assert_response :success
      end

      context 'creating a column' do
        subject do
          { :action => :create,
            :column => {
              :ptype   => 'string',
              :name    => 'philosopher',
              :role_id => roles_id(:Letter)
            }
          }
        end

        should 'create a new Column' do
          assert_difference('Column.count', 1) do
            post_subject
          end
        end

        should 'set name, ptype and role_id' do
          post_subject
          column = assigns(:column)
          assert_equal 'philosopher',    column.name
          assert_equal 'string',    column.ptype
          assert_equal roles_id(:Letter), column.role_id
        end

        should 'redirect to show' do
          post_subject
          assert_redirected_to column_path(assigns(:column))
        end

      end # creating a virtual class

      context 'displaying a virtual class' do
        subject do
          {:action => :show, :id => columns_id(:Task_assigned)}
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # displaying a virtual class

      context 'editing a virtual class' do
        subject do
          {:action => :edit, :id => columns_id(:Task_assigned)}
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # editing a virtual class

      context 'updating a virtual class' do
        subject do
          {:action => :update, :id => columns_id(:Task_assigned), :column => { :name => 'foobar'}}
        end

        should 'redirect to show' do
          put_subject
          assert_redirected_to column_path(assigns(:column))
        end

        should 'save name' do
          put_subject
          column = assigns(:column)
          assert_equal 'foobar', column.name
        end

      end # updating a virtual class

      context 'destroying a column' do
        subject do
          {:action => :destroy, :id => columns_id(:Task_assigned)}
        end

        should 'destroy' do
          assert_difference('Column.count', -1) do
            delete_subject
          end
        end

        should 'redirect to index' do
          delete_subject
          assert_redirected_to columns_path
        end
      end # destroying a virtual class
    end # that is an admin
  end # A logged in user
end
