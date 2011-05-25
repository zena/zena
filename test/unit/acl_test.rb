require 'test_helper'

class AclTest < ActiveSupport::TestCase

  context 'An acl' do
    subject do
      acls(:xx)
    end

    should 'authorize if query succeeds' do
      assert subject.authorize?('read', nodes_zip(:wiki))
    end
  end # An acl

end
