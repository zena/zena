require 'test_helper'

class UsersControllerTest < Zena::Controller::TestCase

  context "Accessing index" do
    context "with an admin user" do
      setup do
        login(:lion)
        get :index
      end

      should_assign_to :users
      should_render_with_layout :_main
      should_respond_with :success
    end

    context "with a regular user" do
      setup do
        login(:ant)
        get :index
      end

      should_not_assign_to :users
      should_render_without_layout
      should_respond_with 404
    end

    context "with an invalid layout" do
      setup do
        login(:lion)
        # Make a bad admin layout
        Version.connection.execute "UPDATE #{Version.table_name} SET properties = '{\"data\":{\"title\":\"foo\",\"text\":\"empty\"},\"json_class\":\"Property::Properties\"}' WHERE id = #{versions_id(:Node_admin_layout_zafu_en)}"
        without_files('test.host/zafu') do
            get 'index'
          get 'index'
        end
      end

      should_respond_with :success
      # Renders with default layout "default/Node-+adminLayout.zafu" => compilation as "_main"
      should_render_with_layout :_main
    end

  end

  context "Accessing a user" do
    setup do
      login(:lion)
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

    context 'creating a new user' do
      subject do
        {
          :user   => {
            'name'       => 'Dupont',
            'lang'       => 'fr',
            'time_zone'  => 'Europe/Zurich',
             'status'     => '50',
            'password'   => 'secret',
            'login'      => 'bolomey',
            'first_name' => 'Paul',
            'group_ids'  => [groups_id(:admin), ''],
            'email'      => 'paul.bolomey@brainfuck.com',
            '_'          => '' # This is in the original post
          },
          :action => 'create'
        }
      end

      should 'succeed' do
        post_subject
        assert_response :success
        user = assigns(:user)
        assert !user.new_record?
      end

      should 'create a new user' do
        assert_difference('User.count', 1) do
          post_subject
        end
      end

      should 'create a new node' do
        assert_difference('Node.count', 1) do
          post_subject
        end
      end
    end # creating a new user
  end # With an admin user


  context 'Accessing preferences' do
    setup do
      login(:ant)
      get(:preferences, {'id'=>visitor.id})
    end

    should_respond_with :success
    should_render_with_layout :_main
  end

  context "Updating a user" do
    setup do
      login(:lion)
      put 'update', 'id' => users_id(:lion), 'user'=>{'name'=>'Leo Verneyi', 'lang'=>'en', 'time_zone'=>'Africa/Algiers', 'first_name'=>'Panthera', 'login'=>'lion', 'email'=>'lion@zenadmin.info'}
    end
    should_assign_to :user
    should_respond_with :success
    should "be able to set timezone" do
      assert_equal 'Africa/Algiers', assigns(:user)[:time_zone]
    end
  end # Updating a user
end