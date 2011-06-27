require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class AclIntegrationTest < Zena::Integration::TestCase

  context 'A visitor' do
    setup do
      $_test_site = 'erebus'
    end

    context 'with normal access' do
      setup do
        post 'http://erebus.host/session', :login=>'hades', :password=>'hades'
        assert_redirected_to 'http://erebus.host/oo'
      end

      should 'find nodes' do
        get "http://erebus.host/oo/project#{nodes_zip(:over_zeus)}.html"
        assert_response :success
        assert_match %r{there is "A plan to overrule Zeus"}, response.body
      end
    end # with normal access

    context 'without normal access' do
      setup do
        post 'http://erebus.host/session', :login=>'demeter', :password=>'demeter'
      end

      context 'with acl enabled' do
        should 'redirect to visitor home on login' do
          assert_redirected_to 'http://erebus.host/oo'
          follow_redirect!
          assert_redirected_to 'http://erebus.host/oo/contact12.html'
          follow_redirect!
          assert_response :success
        end

        should 'redirect to visitor home on root' do
          get 'http://erebus.host/oo'
          assert_redirected_to 'http://erebus.host/oo/contact12.html'
          follow_redirect!
          assert_response :success
        end

        should 'find node in acl scope' do
          get "http://erebus.host/oo/project#{nodes_zip(:queen)}.html"
          assert_response :success
        end

        should 'render with forced skin' do
          get "http://erebus.host/oo/project#{nodes_zip(:queen)}.html"
          assert_match %r{you can see \"My Queen\"}, response.body
        end

        should 'find items in view with exec_group' do
          get "http://erebus.host/oo/project#{nodes_zip(:queen)}.html"
          assert_match %r{Persephone, Wedding organization}, response.body
        end

        context 'with fixed mode' do
          setup do
            Zena::Db.execute "UPDATE acls SET mode = 'foo' WHERE id = #{acls_id(:rap)}"
            login(:hades)
            # Create special mode template
            secure(Template) { Template.create(:parent_id => nodes_id(:sky), :title => 'Node-foo', :text => 'foo <r:title/>') }
            post 'http://erebus.host/session', :login=>'demeter', :password=>'demeter'
          end

          should 'not allow another mode' do
            get "http://erebus.host/oo/project#{nodes_zip(:queen)}.html"
            assert_response :missing
          end

          should 'allow given mode' do
            get "http://erebus.host/oo/project#{nodes_zip(:queen)}_foo.html"
            assert_response :success
            assert_equal 'foo My Queen', response.body
          end
        end # with fixed mode

        context 'with fixed format' do
          setup do
            Zena::Db.execute "UPDATE acls SET format = 'csv' WHERE id = #{acls_id(:rap)}"
            login(:hades)
            # Create special mode template
            secure(Template) { Template.create(:parent_id => nodes_id(:sky), :title => 'Node--csv', :text => 'foo;<r:title/>') }
            post 'http://erebus.host/session', :login=>'demeter', :password=>'demeter'
          end

          should 'not allow another mode' do
            get "http://erebus.host/oo/project#{nodes_zip(:queen)}.html"
            assert_response :missing
          end

          should 'allow given mode' do
            get "http://erebus.host/oo/project#{nodes_zip(:queen)}.csv"
            assert_response :success
            assert_equal 'foo;My Queen', response.body
          end
        end # with fixed format

        context 'using zafu ajax' do
          setup do
            @zafu_url = "http://erebus.host/nodes/#{nodes_zip(:queen)}/zafu?t_url=Sky%20view/Node/list1&dom_id=list1"
            filepath = Pathname("#{SITES_ROOT}/erebus.host/zafu/Sky view/Node/en/list1.erb")
            FileUtils.mkpath(filepath.parent)
            File.open(filepath, 'wb') do |f|
              f.puts "Zafu safe ok"
            end
          end

          should 'not allow t_url not in rendering skin' do
            # Stupid tests. Raises ActionView::TemplateError during testing and
            # ActiveRecord::RecordNotFound in production.
            get @zafu_url.sub('Sky%20view', 'Under%20World')
            assert_response 500
          end

          should 'allow t_url in rendering skin' do
            get @zafu_url
            assert_response :success
            assert_equal %{Element.replace("list1", "Zafu safe ok\\n");\n}, response.body
          end
        end # using zafu ajax

        should 'not find node out of acl scope' do
          get "http://erebus.host/oo/project#{nodes_zip(:persephone)}.html"
          assert_response :missing
        end

        context 'using method without acl' do
          should 'not find node out of acl scope' do
            put "http://erebus.host/nodes/#{nodes_zip(:queen)}"
            assert_response :missing

            delete "http://erebus.host/nodes/#{nodes_zip(:queen)}"
            assert_response :missing

            post "http://erebus.host/nodes?node[parent_id]=#{nodes_zip(:queen)}"
            assert_response :missing
          end
        end # using method without acl
      end # with acl enabled

      context 'with acl for create enabled' do
        setup do
          # The visitor can create objects in assigned_project as direct parent
          Zena::Db.execute "UPDATE acls SET query = 'assigned_project', action = 'create' WHERE id = #{acls_id(:rap)}"
          @create_url = "http://erebus.host/nodes?node[parent_id]=#{nodes_zip(:queen)}&node[klass]=Page&node[title]=foobar"
        end

        context 'with wrong user status' do
          should 'not create item' do
            assert_difference('Node.count', 0) do
              post @create_url
            end
          end
        end # with wrong user status

        context 'with correct user status' do
          setup do
            Zena::Db.execute "UPDATE users SET status = #{User::Status[:user]} WHERE id = #{users_id(:demeter)}"
          end

          should 'create item' do
            assert_difference('Node.count', 1) do
              post @create_url
            end
            node = assigns(:node)
            assert_equal visitor.id, node.user_id
            assert_equal nodes_id(:queen), node.parent_id
            assert_equal 'foobar', node.title
          end

          should 'not create item out of acl scope' do
            assert_difference('Node.count', 0) do
              post "http://erebus.host/nodes?node[parent_id]=#{nodes_zip(:persephone)}&node[klass]=Page&node[title]=foobar"
            end
            assert_response :missing
          end

          context 'without use acl' do
            setup do
              Zena::Db.execute "UPDATE users SET use_acls = #{Zena::Db.quote(false)}"
            end

            should 'not create item' do
              assert_difference('Node.count', 0) do
                post @create_url
              end
              assert_response :missing
            end
          end # without use acl
        end # with correct user status
      end # with acl for create enabled


      context 'with acl for update enabled' do
        setup do
          # The visitor can update objects in assigned_project
          Zena::Db.execute "UPDATE acls SET query = 'nodes in project from assigned_project', action = 'update' WHERE id = #{acls_id(:rap)}"
          @update_url = "http://erebus.host/nodes/#{nodes_zip(:persephone)}?node[title]=foobar"
        end

        context 'with wrong user status' do
          should 'not update item' do
            put @update_url
            node = assigns(:node)
            assert_equal 'You do not have the rights to edit.', node.errors[:base]
          end
        end # with wrong user status

        context 'with correct user status' do
          setup do
            Zena::Db.execute "UPDATE users SET status = #{User::Status[:user]} WHERE id = #{users_id(:demeter)}"
          end

          should 'update item' do
            put @update_url
            assert_equal 'foobar', nodes(:persephone).title
          end

          should 'not update item out of acl scope' do
            put "http://erebus.host/nodes/#{nodes_zip(:queen)}?node[title]=foobar"
            assert_response :missing
          end

          context 'without use acl' do
            setup do
              Zena::Db.execute "UPDATE users SET use_acls = #{Zena::Db.quote(false)}"
            end

            should 'not update item' do
              put @update_url
              assert_response :missing
            end
          end # without use acl
        end # with correct user status
      end # with acl for update enabled


      context 'with acl for delete enabled' do
        setup do
          # The visitor can delete objects in assigned_project
          Zena::Db.execute "UPDATE acls SET query = 'nodes in project from assigned_project', action = 'delete' WHERE id = #{acls_id(:rap)}"
          @delete_url = "http://erebus.host/nodes/#{nodes_zip(:persephone)}"
        end

        context 'with wrong user status' do
          should 'not delete item' do
            assert_difference('Node.count', 0) do
              delete @delete_url
            end
          end
        end # with wrong user status

        context 'with correct user status' do
          setup do
            Zena::Db.execute "UPDATE users SET status = #{User::Status[:user]} WHERE id = #{users_id(:demeter)}"
          end

          should 'delete item' do
            assert_difference('Node.count', -1) do
              delete @delete_url
            end
          end

          should 'not delete item out of acl scope' do
            assert_difference('Node.count', 0) do
              delete "http://erebus.host/nodes/#{nodes_zip(:secret_weapon)}"
            end
            assert_response :missing
          end
        end # with correct user status

        context 'without use acl' do
          setup do
            Zena::Db.execute "UPDATE users SET use_acls = #{Zena::Db.quote(false)}"
          end

          should 'not delete item' do
            assert_difference('Node.count', 0) do
              delete @delete_url
            end
            assert_response :missing
          end
        end # without use acl
      end # with acl for delete enabled
    end # without normal access
  end # a visitor
end