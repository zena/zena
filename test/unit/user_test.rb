require File.dirname(__FILE__) + '/../test_helper'

class UserTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def test_cannot_destroy_su
    su = users(:su)
    assert_kind_of User, su
    assert_raise(Zena::AccessViolation){ su.destroy }
  end
  
  def test_cannot_destroy_anon
    anon = users(:anon)
    assert_kind_of User, anon
    assert_raise(Zena::AccessViolation){ anon.destroy }
  end
  
  def test_can_destroy_ant
    ant = users(:ant)
    assert_kind_of User, ant
    assert_nothing_raised( Zena::AccessViolation ) { ant.destroy }
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
  
  def test_anon_cannot_login
    assert_nil User.login('anon', '')
  end
  
  def test_unique_login
    bob = User.new
    bob.login = 'ant'
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
  
  def test_comments_to_publish
    # status pgroup = managers
    node = nodes(:status)
    assert_equal groups_id(:managers), node.pgroup_id
    # tiger in managers
    tiger = users(:tiger)
    to_publish = tiger.comments_to_publish
    assert_equal 1, to_publish.size
    assert_equal 'Nice site', to_publish[0][:title]
    
    # ant not in managers
    ant = users(:ant)
    to_publish = ant.comments_to_publish
    assert_equal 0, to_publish.size
  end
  
  # TODO: finish tests for User
  # groups
end
=begin
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
