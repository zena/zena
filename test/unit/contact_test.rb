require 'test_helper'

class ContactTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  def test_user
    login(:anon)
    contact = secure!(Node) { nodes(:tiger) }
    assert user = contact.user
    assert_kind_of User, user
    assert_equal users_id(:tiger), user[:id]
  end
  
  def test_update_content
    login(:tiger)
    contact = secure!(Node) { nodes(:tiger) }
    assert_equal 'Panther', contact.c_first_name
    assert_equal 'Tigris Sumatran', contact.c_name
    c_id = contact.c_id
    v_id = contact.v_id
    assert contact.update_attributes(:c_first_name => 'Roger', :c_name => 'Rabbit', :v_status => Zena::Status[:pub])
    
    contact = secure!(Node) { nodes(:tiger) }
    assert_not_equal c_id, contact.c_id # new contact record
    assert_not_equal v_id, contact.v_id # new version record
    assert_equal 'Roger', contact.c_first_name
    assert_equal 'Rabbit', contact.c_name
    c_id = contact.c_id
    v_id = contact.v_id
    
    assert contact.update_attributes(:v_text => 'foo')
    
    contact = secure!(Node) { nodes(:tiger) }
    assert_equal c_id, contact.c_id # not a new contact record
    assert_not_equal v_id, contact.v_id # new version record
    assert_equal v_id, contact.v_content_id
    assert_equal 'Roger', contact.c_first_name
    assert_equal 'Rabbit', contact.c_name
  end
end
