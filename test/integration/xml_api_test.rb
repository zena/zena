require 'test_helper'

class XmlApiTest < Zena::Integration::TestCase

  class NodeResource < ActiveResource::Base
    headers['HTTP_X_AUTHENTICATION_TOKEN'] = 'mytoken'
    include Zena::Integration::MockResource
    self.site         = 'http://test.host'
    self.element_name = 'node'
  end

  class BadTokenResource < ActiveResource::Base
    headers['HTTP_X_AUTHENTICATION_TOKEN'] = 'some-bad-token'
    include Zena::Integration::MockResource
    self.site         = 'http://test.host'
    self.element_name = 'node'
  end

  context 'With an authentification token' do
    setup do
      test_site(:zena)
      init_test_connection!
    end

    context 'reading a node' do
      subject do
        NodeResource.find(nodes_zip(:status))
      end

      should 'succeed' do
        assert_nothing_raised { subject }
      end

      should 'read attributes' do
        assert_equal 'status title', subject.title
      end
    end # reading a node

    context 'searching for nodes' do
      subject do
        node = secure!(Node) { nodes(:art) }
        node.update_attributes(:title => 'Dada', :v_status => Zena::Status[:pub])
        node
      end

      should 'succeed' do
        subject # create index entry
        assert_nothing_raised { NodeResource.find(:all, :from => '/nodes/search', :params => {:title => 'Dada'}) }
      end

      should 'find the list of nodes' do
        subject # create index entry for art
        # create index entry for status
        node = secure!(Node) { nodes(:status) }
        node.update_attributes(:title => 'Fuda', :v_status => Zena::Status[:pub])

        result = NodeResource.find(:all,
          :from   => '/nodes/search',
          :params => {:title => 'Fuda'}
        ).map(&:id)

        assert_equal [nodes_zip(:status)], result
      end
      
      should 'find the list of nodes with qb' do
        subject # create index entry for art
        # create index entry for status
        node = secure!(Node) { nodes(:status) }
        node.update_attributes(:title => 'Fuda', :v_status => Zena::Status[:pub])

        result = NodeResource.find(:all,
          :from   => '/nodes/search',
          :params => {:qb => 'nodes where title like "%da%" in site'}
        ).map(&:id)

        assert_equal [nodes_zip(:art), nodes_zip(:status)], result
      end

      should 'find the list of nodes with fulltext' do
        subject # create index entry for art

        result = NodeResource.find(:all,
          :from   => '/nodes/search',
          :params => {:q => 'da'}
        ).map(&:id)

        assert_equal [nodes_zip(:art)], result
      end

      context 'returning nothing' do
        should 'return an empty list' do
          assert_equal [], NodeResource.find(:all, :from => '/nodes/search', :params => {:title => 'Foobar'})
        end
      end # returning empty

    end # reading a node

    context 'updating a node' do
      subject do
        NodeResource.find(nodes_zip(:status))
      end

      should 'succeed' do
        assert_nothing_raised do
          subject.attributes.merge!('origin' => 'foobar')
          subject.save
        end
      end

      should 'save content to remote db' do
        subject.attributes.merge!('title' => 'cloud')
        assert subject.save
        assert_equal 'cloud', nodes(:status).title
      end
    end # updating a node

    context 'creating a node with klass' do
      subject do
        # Letter should load 'paper' property
        NodeResource.new(:parent_id => nodes_zip(:people), :klass => 'Letter', :paper => 'manila', :title => 'Hey')
      end

      should 'succeed' do
        assert_nothing_raised do
          subject.save
        end
      end
    end # updating a node

    context 'destroying a node' do
      subject do
        nodes_zip(:art)
      end

      should 'succeed' do
        assert_nothing_raised do
          NodeResource.find(subject).destroy
        end
      end

      should 'delete the node' do
        assert_difference('Node.count', -1) do
          NodeResource.find(subject).destroy
        end
      end
    end # 'destroying a node'

  end # With an authentification token

  context 'Without an authentification token' do
    setup do
      test_site(:zena)
      init_test_connection!
    end

    context 'reading a node' do
      subject do
        BadTokenResource.find(nodes_zip(:status))
      end

      should 'raise ActiveResource::UnauthorizedAccess' do
        assert_raise(ActiveResource::UnauthorizedAccess) { subject }
      end
    end # reading a node
  end # With an aunthentified user
end