require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ZenaTestUnit

  
  def test_cannot_destroy_su
    su = users(:su)
    assert_raise(Zena::RecordNotSecured){ su.destroy }
    login(:su)
    su = secure(User) { users(:su) }
    assert_raise(Zena::AccessViolation){ su.destroy }
  end
  
  def test_cannot_destroy_anon
    anon = users(:anon)
    assert_raise(Zena::RecordNotSecured){ anon.destroy }
    login(:su)
    anon = secure(User) { users(:anon) }
    assert_raise(Zena::AccessViolation){ anon.destroy }
  end
  
  def test_can_destroy_ant
    assert_raise(Zena::RecordNotSecured){ users(:ant).destroy }
    login(:lion)
    ant = secure(User) { users(:ant) }
    assert_nothing_raised( Zena::AccessViolation ) { ant.destroy }
  end
  
  def test_create
    login(:whale)
    User.connection.execute "UPDATE users SET lang='ru', time_zone='Hawaii'"
    user = secure(User) { User.create("login"=>"john", "password"=>"isjjna78a9h") }
    assert !user.new_record?, "Not a new record"
    user = secure(User) { User.find(user[:id]) } # reload
    assert user.sites.include?(sites(:ocean))
    assert_equal 2, user.groups.size
    assert user.groups.include?(groups(:pub_ocean)), "Is in the public group"
    assert user.groups.include?(groups(:aqua)), "Is in the 'site' group"
    assert_equal User::Status[:moderated], user.status
    assert_equal 'ru', user.lang
    assert_equal 'Hawaii', user[:time_zone]
    assert !user.user?, "Not a real user yet"
    assert visitor.user?, "Whale is a user"
  end
  
  def test_create_admin_with_groups
    login(:lion)
    user = secure(User) { User.new("login"=>"john", "password"=>"isjjna78a9h", "group_ids"=>[groups_id(:admin)]) }
    assert user.save
    user = secure(User) { User.find(user[:id])}
    assert_equal 3, user.groups.size
  end
  
  def test_update_keep_password
    login(:tiger)
    user = secure(User) { users(:tiger) }
    pass = user[:password]
    assert pass != "", "Password not empty"
    assert user.update_attributes(:login=>'bigme', :password=>'')
    assert_equal 'bigme', user.login
    assert_equal pass, user[:password]
  end
  
  def test_only_self_or_admin_can_update
    login(:tiger)
    user = secure(User) { users(:ant) }
    user.email = "eat@spam.com"
    assert !user.save
    assert user.errors[:base]
    user = secure(User) { users(:tiger) }
    user.email = "socr@isa.man"
    assert user.save
    assert_equal "socr@isa.man", user.email
  end
  
  def test_only_admin_can_create
    login(:tiger)
    user = secure(User) { User.create(:login=>'joe', :password=>'whatever') }
    assert user.new_record?
    assert user.errors[:base]
    login(:lion)
    user = secure(User) { User.create(:login=>'joe', :password=>'whatever') }
    assert !user.new_record?
  end
  
  def test_anon_cannot_login
    assert_nil User.login('anon', '', sites(:zena))
  end
  
  def test_unique_login
    login(:lion)
    bob = secure(User) { User.create(:login=>'tiger', :password=>'anypassword') }
    assert bob.new_record?
    assert_not_nil bob.errors[:login]
    
    login(:whale)
    bob = secure(User) { User.create(:login=>'tiger', :password=>'anypassword') }
    assert !bob.new_record?
    assert_nil bob.errors[:login]
  end
  
  def test_empty_password
    login(:lion)
    bob = secure(User) { User.new }
    bob.login = 'bob'
    bob.save
    assert ! bob.save
    assert_not_nil bob.errors[:password]
  end
  
  def test_update_public
    login(:lion)
    pub = secure(User) { users(:anon) }
    assert_equal 'en', pub.lang
    assert_nil pub.login
    assert_nil pub[:password]
    
    pub.login = "hello"
    pub.password = 'heyjoe'
    pub.lang = 'es'
    assert pub.save
    assert_equal 'es', pub.lang
    assert_equal nil, pub.login
    assert_equal nil, pub[:password]
  end
  
  def test_comments_to_publish
    login(:tiger)
    # status pgroup = managers
    node = nodes(:status)
    assert_equal groups_id(:managers), node.pgroup_id
    # tiger in managers
    to_publish = visitor.comments_to_publish
    assert_equal 1, to_publish.size
    assert_equal 'Nice site', to_publish[0][:title]
    
    # ant not in managers
    login(:ant)
    to_publish = visitor.comments_to_publish
    assert_equal 0, to_publish.size
  end
  
  def test_is_admin
    login(:ant)
    user = secure(User) { users(:lion) }
    assert user.is_admin?
  end
  
  def test_group_ids
    login(:ant)
    user = secure(User) { users(:tiger) }
    assert_equal [groups_id(:managers), groups_id(:public), groups_id(:site)], user.group_ids
    user = secure(User) { users(:lion) }
    assert_equal [groups_id(:admin), groups_id(:managers), groups_id(:public), groups_id(:site)], user.group_ids
  end
  
  def test_add_to_site
    login(:lion)
    user = secure(User) { User.new(:login=>'joe', :password=>'secret', :site_ids=>['1','2'])}
    assert_raise(Zena::AccessViolation) { user.save }
    
    # make lion a user of ocean
    Group.connection.execute "INSERT INTO sites_users (site_id, user_id) VALUES (#{sites_id(:ocean)}, #{users_id(:lion)})"
    login(:lion)
    user = secure(User) { User.new(:login=>'joe', :password=>'secret', :site_ids=>[sites_id(:zena),sites_id(:ocean)])}
    assert_raise(Zena::AccessViolation) { user.save }
    
    # make lion an admin in ocean
    Group.connection.execute "INSERT INTO groups_users (group_id, user_id) VALUES (#{groups_id(:masters)}, #{users_id(:lion)})"
    login(:lion)
    user = secure(User) { User.new(:login=>'joe', :password=>'secret', :site_ids=>[sites_id(:zena),sites_id(:ocean)])}
    assert user.save
    assert user.sites.include?(sites(:zena))
    assert user.sites.include?(sites(:ocean))
  end
end
