require 'test_helper'

class XmlApiTest < Zena::Integration::TestCase
  class NodeResource < ActiveResource::Base
    include Zena::Integration::MockResource
    self.site         = 'http://test.host'
    self.element_name = 'node'
  end

  context 'With an authentification token' do
    setup do
      test_site(:zena)
      NodeResource.password = 'mytoken'
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

    context 'updating a node' do
      subject do
        NodeResource.find(nodes_zip(:status))
      end

      should 'succeed' do
        assert_nothing_raised do
          subject.attributes.merge!('title' => 'cloud')
          subject.save
        end
      end

      should 'save content to remote db' do
        subject.attributes.merge!('title' => 'cloud')
        assert subject.save
        assert_equal 'cloud', nodes(:status).title
      end
    end # updating a node
  end # With an authentification token

  context 'Without an authentification token' do
    setup do
      test_site(:zena)
      NodeResource.password = nil
      init_test_connection!
    end

    context 'reading a node' do
      subject do
        NodeResource.find(nodes_zip(:status))
      end

      should 'raise ActiveResource::UnauthorizedAccess' do
        assert_raise(ActiveResource::UnauthorizedAccess) { subject }
      end
    end # reading a node
  end # With an aunthentified user
end