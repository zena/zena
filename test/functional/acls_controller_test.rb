require 'test_helper'

class AclsControllerTest < Zena::Controller::TestCase

  context 'A visitor' do
    setup do
      login(:persephone)
    end

    context 'viewing index' do

      should 'respond missing' do
        get :index
        assert_response :missing
      end

      context 'with admin rights' do
        setup do
          login(:hades)
        end

        should 'view list of acls' do
          get :index
          assert_response :success
        end
      end # with admin rights

    end # viewing index


    context 'creating an acl' do

      should 'respond missing' do
        assert_difference('Acl.count', 0) do
          post :create, :acl => { :query => '%q{assigned_project}', :group_id => groups_id(:sky) }
        end

        assert_response :missing
      end

      context 'with admin rights' do
        setup do
          login(:hades)
        end

        should 'create acl' do
          assert_difference('Acl.count', 1) do
            post :create, :acl => { :query => '%q{assigned_project}', :group_id => groups_id(:sky) }
          end
        end
        
        should 'not create acl with bad kpath' do
          assert_difference('Acl.count', 0) do
            post :create, :acl => { :query => '%q{assigned_project}', :group_id => groups_id(:sky), :create_kpath => 'TRI' }
          end
        end
      end # with admin rights

    end # creating an acl

    context 'updating an acl' do

      should 'respond missing' do
        put :update, :id => acls_id(:rap), :acl => {:name => 'foobar'}
        assert_response :missing
      end

      context 'with admin rights' do
        setup do
          login(:hades)
        end

        should 'change acl' do
          put :update, :id => acls_id(:rap), :acl => {:name => 'foobar'}, :format => 'js'
          assert_response :success
          err assigns(:acl)
          assert_equal 'foobar', acls(:rap).name
        end
      end # with admin rights

    end # updating an acl

    context 'deleting an acl' do

      should 'respond missing' do
        delete :destroy, :id => acls_id(:rap)
        assert_response :missing
      end

      context 'with admin rights' do
        setup do
          login(:hades)
        end

        should 'delete acl' do
          assert_difference('Acl.count', -1) do
            delete :destroy, :id => acls_id(:rap)
          end
          assert_redirected_to :action => 'index'
        end
      end # with admin rights

    end # deleting an acl
  end # A visitor
end
