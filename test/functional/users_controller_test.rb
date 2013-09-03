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
        Version.connection.execute "UPDATE #{Version.table_name} SET properties = '{\"data\":{\"title\":\"foo\",\"text\":\"empty\",\"tkpath\":\"N\"},\"json_class\":\"Property::Properties\"}' WHERE id = #{versions_id(:Node_admin_layout_zafu_en)}"
        without_files('test.host/zafu') do
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
            'lang'       => 'fr',
            'time_zone'  => 'Europe/Zurich',
            'status'     => '50',
            'password'   => 'secret',
            'login'      => 'bolomey',
            'group_ids'  => [groups_id(:admin), ''],
            'infamous'   => '' # This is to test bad blank values
          },
          '_'          => '', # This is in the original post
          :action => 'create',
          :node   => {
            'name'  => 'Dupont',
            'first_name' => 'Paul',
            'email'      => 'paul.bolomey@brainfuck.com',
          },
        }
      end

      should 'succeed' do
        assert_difference('User.count', 1) do
          post_subject
          assert_response :success
          user = assigns(:user)
        end
      end

      should 'create a new node' do
        assert_difference('Node.count', 1) do
          post_subject
        end
      end

      should 'set node attributes' do
        post_subject
        node = secure(Node) { Node.find(assigns(:user).node_id) }
        assert_equal 'Dupont', node.name
        assert_equal 'Paul', node.first_name
        assert_equal 'paul.bolomey@brainfuck.com', node.email
      end

      context 'with an existing node' do
        subject do
          {
            :user   => {
              'lang'       => 'fr',
              'time_zone'  => 'Europe/Zurich',
              'status'     => '50',
              'password'   => 'secret',
              'login'      => 'bolomey',
              'group_ids'  => [groups_id(:admin), ''],
              'infamous'   => '' # This is to test bad blank values
            },
            '_'          => '', # This is in the original post
            :action => 'create',
            :node   => {
              'id'    => 'Solen',
              'name'  => 'Dupont',
              'first_name' => 'Paul',
              'email'  => 'paul.bolomey@brainfuck.com',
            },
          }
        end

        should 'succeed' do
          assert_difference('User.count', 1) do
            post_subject
            assert_response :success
            user = assigns(:user)
          end
        end

        should 'not create a new node' do
          assert_difference('Node.count', 0) do
            post_subject
          end
        end

        should 'set node attributes' do
          post_subject
          node = secure(Node) { Node.find(assigns(:user).node_id) }
          assert_equal nodes_id(:ant), node.id
          assert_equal 'Dupont', node.name
          assert_equal 'Paul', node.first_name
          assert_equal 'paul.bolomey@brainfuck.com', node.email
        end
      end # with an existing node
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
      put 'update',
        'id' => users_id(:lion),
        'user'=> {
          'lang'=>'en',
          'time_zone'=>'Africa/Algiers',
          'login'=>'lion',
        }
    end

    should_assign_to :user

    should_respond_with :success

    should "set timezone" do
      err assigns(:user)
      assert_equal 'Africa/Algiers', users(:lion)[:time_zone]
    end
  end # Updating a user

  context "Changing password" do
    setup do
      login(:ant)
    end

    subject do
      put 'update',
        'id'     => users_id(:ant),
        'update' => 'pass',
        'user'   => {
          'password'        => 'superman',
          'retype_password' => 'superman',
          'old_password'    => 'ant'
        }
    end

    should 'set password' do
      subject
      assert_response :success
      assert users(:ant).valid_password?('superman')
    end

    context 'with an invalid previous password' do
      subject do
        put 'update',
          'id'     => users_id(:ant),
          'update' => 'pass',
          'user'   => {
            'password'        => 'superman',
            'retype_password' => 'superman',
            'old_password'    => 'antaddf'
          }
      end

      should 'not change password' do
        subject
        assert_response :success
        assert !users(:ant).valid_password?('superman')
        assert users(:ant).valid_password?('ant')
      end

      should 'set an error' do
        subject
        assert_equal 'not correct', assigns(:user).errors[:old_password]
      end
    end # with an invalid previous password

    context 'by an admin' do
      setup do
        login(:lion)
      end

      subject do
        put 'update',
          'id'     => users_id(:lion),
          'update' => 'pass',
          'user'   => {
            'password'        => 'superman',
            'retype_password' => 'superman',
            'old_password'    => 'lion'
          }
      end

      should 'set password' do
        subject
        assert_response :success
        assert users(:lion).valid_password?('superman')
      end

      should 'set other user password' do
        put 'update',
          'id'     => users_id(:ant),
          'update' => 'pass',
          'user'   => {
            'password'        => 'cymbal'
          }
        assert_response :success
        assert users(:ant).valid_password?('cymbal')
      end

      should 'not set own password without previous password' do
        put 'update',
          'id'     => users_id(:lion),
          'update' => 'pass',
          'user'   => {
            'password'        => 'cymbal'
          }
        assert_response :success
        assert_equal 'not correct', assigns(:user).errors[:old_password]
      end

      context 'with an invalid previous password' do
        subject do
          put 'update',
            'id'     => users_id(:lion),
            'update' => 'pass',
            'user'   => {
              'password'        => 'superman',
              'retype_password' => 'superman',
              'old_password'    => 'antaddf'
            }
        end

        should 'not change password' do
          subject
          assert_response :success
          assert !assigns(:user).valid_password?('superman')
          assert assigns(:user).valid_password?('lion')
        end

        should 'set an error' do
          subject
          assert_equal 'not correct', assigns(:user).errors[:old_password]
        end
      end # with an invalid previous password
    end # by an admin

  end # Changing password
end