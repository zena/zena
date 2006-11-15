require File.dirname(__FILE__) + '/../test_helper'

class UserTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def test_cannot_destroy_su
    su = User.find(addresses_id(:su))
    assert_kind_of User, su
    assert_raise(Zena::AccessViolation){ su.destroy }
  end
  
  def test_create_admin_with_groups
    user = User.new("login"=>"john", "password"=>"isjjna78a9h", "group_ids"=>["1", "2"])
    assert user.save
    assert_equal 2, user.groups.size
  end
  
  def test_create_without_groups
    user = User.new("login"=>"john", "password"=>"isjjna78a9h")
    assert user.save
    assert_equal 1, user.groups.size
    assert_equal 'public', user.groups[0].name
  end
  
  def test_to_do
    assert false
  end
end
=begin
  def test_truth
    assert_kind_of User, contacts(:gaspard)
  end
  
  def test_kai_groups
    kai = User.find(contacts(:kai).id)
    assert_kind_of User, kai
    gps = kai.groups
    gps.map!{|g| g.id}
    assert_equal 2, gps.size
    assert gps.include?(groups(:direction).id)
    assert gps.include?(groups(:public).id)
  end
  
  def test_gaspard_groups
    gaspard = User.find(contacts(:gaspard).id)
    assert_kind_of User, gaspard
    gps = gaspard.groups
    assert_equal 4, gps.size
    assert_equal [1,2,3,4], gaspard.group_ids
  end
  
  def test_beatrice_groups
    beatrice = Contact.find(contacts(:beatrice).id)
    assert_kind_of Contact, beatrice
  end
  
  def test_cannot_destroy_su
    su = User.find(contacts(:su).id)
    assert_kind_of User, su
    assert_raise(Zena::AccessViolation){ su.destroy }
  end
  
  def test_cannot_destroy_anon
    anon = User.find(contacts(:anon).id)
    assert_kind_of User, anon
    assert_raise( Zena::AccessViolation ){ anon.destroy }
  end
  
  def test_can_destroy_gaspard
    gaspard = User.find(contacts(:gaspard).id)
    assert_kind_of User, gaspard
    assert_nothing_raised ( Zena::AccessViolation ) { gaspard.destroy }
  end
  
  def test_anon_cannot_login
    assert_nil User.login('anon', '')
  end
  
  def test_unique_login
    bob = User.new
    bob.login = 'gaspard'
    bob.password = 'bob'
    assert ! bob.save
    assert_not_nil bob.errors[:login]
    
    bob.login = 'bob'
    assert bob.save
    assert_nil bob.errors[:login]
  end
  
  def test_empty_password
    bob = User.new
    bob.login = 'bob'
    assert ! bob.save
    assert_not_nil bob.errors[:password]
  end
  
  
  ### ================================================ ACTIONS AND OWNED ITEMS
  def test_versions_to_publish
    gaspard = contacts(:gaspard)
    kai = contacts(:kai)
    assert_equal 1, kai.versions_to_publish.size
    assert_equal 2, gaspard.versions_to_publish.size
  end
  def test_redactions
    gaspard = contacts(:gaspard)
    assert_equal 2, gaspard.redactions.size
    kai = contacts(:kai)
    assert_equal 0, kai.redactions.size
  end
  def test_proposed_versions
    gaspard = contacts(:gaspard)
    assert_equal 1, gaspard.proposed_versions.size
    assert_equal versions(:zena_fr_proposed).id, gaspard.proposed_versions[0].id
    kai = contacts(:kai)
    assert_equal 1, kai.proposed_versions.size
    assert_equal versions(:management_en_prop).id, kai.proposed_versions[0].id
  end
end
=end
