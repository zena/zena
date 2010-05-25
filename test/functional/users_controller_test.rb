require 'test_helper'

class UsersControllerTest < Zena::Controller::TestCase

  context "on GET index" do
    context " if visitor is admin" do
      setup do
        login(:su)
        get :index
      end

      should_assign_to :users
      should_render_with_layout :_main
      should_respond_with :success
    end

    context " if visitor is not admin" do
      setup do
        login(:ant)
        get :index
      end

      should_not_assign_to :users
      should_render_without_layout
      should_respond_with 404
    end

    context " if layout is invalid" do
      setup do
        login(:lion)
        Version.connection.execute "UPDATE #{Version.table_name} SET text = 'empty' WHERE id = #{versions_id(:Node_admin_layout_zafu_en)}"
        without_files('test.host/zafu') do
          get 'index'
        end
      end

      should_respond_with :success
      should_render_with_layout :_main
    end

  end

  context "on GET show" do
    setup do
      login(:su)
      get(:show, {'id'=>visitor.id})
    end
    
    should 'succeed' do
      assert_response :success
    end
    
    should_render_without_layout
  end

  context 'With an admin user' do
    setup do
      login(:lion)
    end

    context 'setting dev_skin' do
      subject do
        get(:dev_skin, {'skin_id' => nodes_zip(:wikiSkin)})
      end

      should 'store value in visitor properties' do
        subject
        assert_equal nodes_zip(:wikiSkin), visitor.dev_skin_id
      end
    end # setting dev_skin

    context 'calling rescue' do
      subject do
        get(:rescue)
      end

      should 'set dev_skin in visitor properties' do
        subject
        assert_equal -1, visitor.dev_skin_id
      end
    end # setting dev_skin
  end # With an admin user


  context 'on GET preferences' do
    setup do
      login(:su)
      get(:preferences, {'id'=>visitor.id})
    end

    should_respond_with :success
    should_render_with_layout :_main
  end

  context "on PUT" do
    context "in order to update parameters" do
      setup do
        login(:lion)
        put 'update', 'id' => users_id(:lion), 'user'=>{'name'=>'Leo Verneyi', 'lang'=>'en', 'time_zone'=>'Africa/Algiers', 'first_name'=>'Panthera', 'login'=>'lion', 'email'=>'lion@zenadmin.info'}
      end
      should_assign_to :user
      should_respond_with :success
      should "be able to set timezone" do
        assert_equal 'Africa/Algiers', assigns(:user)[:time_zone]
      end
    end
  end


end