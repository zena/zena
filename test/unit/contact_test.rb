require File.dirname(__FILE__) + '/../test_helper'

class ContactTest < ZenaTestUnit

  def test_user
    login(:anon)
    contact = secure(Node) { nodes(:tiger) }
    assert user = contact.user
    assert_kind_of User, user
    assert_equal users_id(:tiger), user[:id]
  end
end
