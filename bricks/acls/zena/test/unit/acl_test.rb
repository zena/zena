require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class AclTest < Zena::Unit::TestCase
  # This is the node from which the query is started.
  def base_node
    visitor.node_without_secure
  end
  MockRequest = Struct.new(:method, :params, :port)

  def mock_request(method = :get, params = {}, port = 0)
    MockRequest.new(method, params, port)
  end

  context 'On a site with acl' do
    setup do
      login(:demeter)
    end

    context 'an acl' do
      subject do
        acls(:rap)
      end

      context 'with a visitor with extended access' do
        setup do
          erebus_id = groups_id(:erebus)
          visitor.instance_eval do
            @group_ids = self.group_ids + [erebus_id]
          end
        end

        context 'with a matching query' do
          should 'authorize' do
            assert subject.authorize?(base_node, {:id => nodes_zip(:queen)}, mock_request)
          end

          should 'return searched node' do
            assert_equal nodes_id(:queen), subject.authorize?(base_node, {:id => nodes_zip(:queen)}, mock_request).id
          end
        end # with a matching query

        context 'with a node outside the query' do
          should 'not authorize' do
            assert_nil subject.authorize?(base_node, {:id => nodes_zip(:over_zeus)}, mock_request)
          end
        end # with a node outside the query

      end # with a visitor with extended access

    end # an acl

    context 'saving an acl with asset_host in query' do
      subject do
        acls(:rap)
      end

      should 'validate' do
        erebus_id = groups_id(:erebus)
        visitor.instance_eval do
          @group_ids = self.group_ids + [erebus_id]
        end
        assert subject.update_attributes(:query => "'nodes where 1 = \#{asset_host? ? 1 : 0} in site'")
        assert_nil subject.authorize?(base_node, {:id => nodes_zip(:over_zeus)}, mock_request)
        visitor.asset_host = true
        assert_equal 'A plan to overrule Zeus', subject.authorize?(base_node, {:id => nodes_zip(:over_zeus)}, mock_request).title
      end
    end # saving an acl with asset_host in query

    context 'saving an acl with an error in rubyless syntax' do
      subject do
        acls(:rap)
      end

      should 'return an error' do
        erebus_id = groups_id(:erebus)
        visitor.instance_eval do
          @group_ids = self.group_ids + [erebus_id]
        end
        assert !subject.update_attributes(:query => "nodes in site")
        assert_equal 'parse error on value ["in", 1] (kIN)', subject.errors[:query]
      end
    end # saving an acl with asset_host in query


    context 'a visitor' do
      context 'with normal access' do
        subject do
          login(:hades)
          visitor
        end

        should 'find nodes' do
          assert_equal nodes(:over_zeus).id,
                       subject.find_node(
                        nil, nodes_zip(:over_zeus), nil, mock_request(:get)
                       ).id
        end
      end # with normal access

      context 'without normal access' do
        subject do
          login(:demeter)
          visitor
        end

        context 'with acl enabled' do
          should 'find node in acl scope' do
            assert_equal nodes(:queen).id,
                         subject.find_node(
                          nil, nodes_zip(:queen), nil, mock_request(:get)
                         ).id
          end

          should 'not find node out of acl scope' do
            assert_raise(ActiveRecord::RecordNotFound) do
              subject.find_node(nil, nodes_zip(:over_zeus), nil, mock_request(:get))
            end
          end

          context 'with many acls' do
            setup do
              Zena::Db.execute "UPDATE acls SET query = \"'nodes in project from assigned_project'\", action = 'read' WHERE id = #{acls_id(:self)}"
            end

            should 'try acls in turn' do
              assert_equal nodes(:wedding).id,
                           subject.find_node(
                            nil, nodes_zip(:wedding), nil, mock_request(:get)
                           ).id
            end
          end # with many acls

          context 'using method without acl' do
            should 'not find node out of acl scope' do
              assert_raise(ActiveRecord::RecordNotFound) do
                subject.find_node(nil, nodes_zip(:queen), nil, mock_request(:put))
              end
              assert_raise(ActiveRecord::RecordNotFound) do
                subject.find_node(nil, nodes_zip(:queen), nil, mock_request(:delete))
              end
              assert_raise(ActiveRecord::RecordNotFound) do
                subject.find_node(nil, nodes_zip(:queen), nil, mock_request(:post))
              end
            end
          end # using method without acl

        end # with acl enabled

        context 'without acl enabled' do
          setup do
            subject.use_acls = false
          end

          should 'not find nodes' do
            assert_raise(ActiveRecord::RecordNotFound) do
              subject.find_node(nil, nodes_zip(:queen), nil, mock_request(:get))
            end
          end
        end # without acl enabled
      end # without normal access
    end # a visitor
  end # On a site with acl
end