require 'test_helper'

class UserTest < Zena::Unit::TestCase

  def test_find_allowed_user_by_login
    login(:anon)
    secure(User) do
      assert_equal users_id(:lion), User.find_allowed_user_by_login('lion').id
    end
  end

  def test_deleted_user_should_not_be_allowed
    User.connection.execute "UPDATE users SET status = #{User::Status[:deleted]} WHERE id = #{users_id(:tiger)} AND site_id = #{sites_id(:zena)}"
    assert_nil User.find_allowed_user_by_login('tiger')
  end

  def test_visited_node_ids
    login(:tiger)
    secure!(Node) { nodes(:status) }
    secure!(Node) { nodes(:bird_jpg) }
    assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
    login(:anon)
    secure!(Node) { nodes(:status) }
    secure!(Node) { nodes(:bird_jpg) }
    assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
    with_caching do
      login(:tiger)
      secure!(Node) { nodes(:status) }
      secure!(Node) { nodes(:bird_jpg) }
      assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
      login(:anon)
      secure!(Node) { nodes(:status) }
      secure!(Node) { nodes(:bird_jpg) }
      assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
    end
  end

  context 'Destroying a user' do
    context 'with admin rights' do
      setup do
        login(:lion)
      end

      should 'not allow anon destruction' do
        assert_raise(Zena::AccessViolation){ users(:anon).destroy }
      end

      should 'not allow destruction of self' do
        assert_raise(Zena::AccessViolation){ users(:lion).destroy }
      end

      should 'allow destruction of regular users' do
        assert_difference('User.count', -1) do
          assert_nothing_raised { users(:ant).destroy }
        end
      end
    end # with admin rights
  end # Destroying a user

  context 'Creating a new User' do
    setup do
      login(:lion)
    end

    subject do
      attrs = {
        'lang'       => 'fr',
        'time_zone'  => 'Europe/Zurich',
        'status'     => '50',
        'password'   => 'secret',
        'login'      => 'bolomey',
        'group_ids'  => [groups_id(:public), ''],
        'node_attributes' => {
          'name'       => 'Dupont',
          'first_name' => 'Paul',
          'email'      => 'paul.bolomey@brainfuck.com'
        }
      }
      secure(User) { User.create(attrs) }
    end

    should 'succeed' do
      assert_difference('User.count', 1) do
        subject
      end
    end

    should 'use missing attributes from prototype' do
      assert_equal 'Iping', subject.node.prop['address']
    end

    context 'with a node id' do
      subject do
        attrs = {
          'lang'       => 'fr',
          'time_zone'  => 'Europe/Zurich',
          'status'     => '50',
          'password'   => 'secret',
          'login'      => 'bolomey',
          'group_ids'  => [groups_id(:public), ''],
          'node_attributes' => {
            'id'       => nodes_zip(:ant)
          }
        }
        secure(User) { User.create(attrs) }
      end

      should 'link to provided node' do
        assert_difference('User.count', 1) do
          assert_difference('Node.count', 0) do
            assert_equal 'Solenopsis Invicta', subject.node.title
          end
        end
      end
    end # with a node id

  end # Creating a new User
  
  context 'Updating a user' do
    setup do
      login(:lion)
    end
    
    subject do
      users(:ant)
    end

    context 'by changing node_id' do
      setup do
        subject.update_attributes('node_attributes' => {'id' => nodes_zip(:lion) })
      end
      
      should 'update link' do
        assert_equal nodes_id(:lion), users(:ant).node_id
      end
    end # by changing node_id
    
  end # Updating a user
  

  context 'Setting node attributes' do
    setup do
      login(:anon)
      subject.node_attributes = {'title' => 'bar'}
    end

    subject do
      User.new
    end

    should 'create a new record' do
      assert subject.node.new_record?
    end

    should 'create a Node of the type defined in prototype attributes' do
      assert_equal 'Contact', subject.node.klass
    end

    context 'more then once' do
      setup do
        @first  = subject.node
        second = User.new
        second.node_attributes = {}
        @second = second.node
      end

      should 'return a new node on each call' do
        assert_not_equal @first.object_id, @second.object_id
      end
    end # more then once
  end # Setting node attributes

  context 'On a user' do
    subject do
      users(:lion)
    end

    should 'evaluate rubyless code in prototype_attributes' do
      assert_equal Hash[
        :_parent_id => subject.site.root_id,
        'klass'     => 'Contact',
        'address'   => 'Iping',
        'name'      => 'lion'], subject.prototype_attributes
    end
  end # On a user

  def test_create
    User.connection.execute "UPDATE users SET lang='ru' WHERE id IN (#{users_id(:incognito)},#{users_id(:whale)})"
    User.connection.execute "UPDATE sites SET languages='fr,ru' WHERE id=#{sites_id(:ocean)}"
    User.connection.execute "UPDATE users SET time_zone='US/Hawaii' WHERE id=#{users_id(:incognito)}"
    login(:whale)

    user = secure!(User) { User.create("login"=>"john", "password"=>"isjjna78a9h", 'node_attributes' => {'v_lang' => 'ru'}) }

    assert !user.new_record?, "Not a new record"
    assert !user.node.new_record?, "Users's contact node is not a new record"

    user = secure!(User) { User.find(user[:id]) } # reload
    assert_equal sites_id(:ocean), user.site_id
    assert_equal 2, user.groups.size
    assert user.groups.map{|g| g.name}.include?('public'), "Is in the public group"
    assert user.groups.map{|g| g.name}.include?('aqua'), "Is in the 'site' group"
    assert_equal User::Status[:moderated], user.status
    assert_equal 'ru', user.lang
    assert_equal 'US/Hawaii', user[:time_zone]
    assert !user.user?, "Not a real user yet"
    assert visitor.user?, "Whale is a user"

    contact = user.node
    assert_equal "john", contact.title
  end

  def test_only_admin_can_create
    login(:tiger)
    user = secure!(User) { User.create("name"=>"Shakespeare", "status"=>"50", "group_ids"=>[""], "lang"=>"fr", "time_zone"=>"Bern", "first_name"=>"William", "login"=>"bob", "password"=>"jsahjks894", "email"=>"") }
    assert user.new_record?, "Not saved"
    assert_equal 'Not found', user.errors[:site]
    assert user.errors[:base] #.any?
    login(:lion)
    user = secure!(User) { User.create("name"=>"Shakespeare", "status"=>"50", "group_ids"=>[""], "lang"=>"fr", "time_zone"=>"Bern", "first_name"=>"William", "login"=>"bob", "password"=>"jsahjks894", "email"=>"") }
    assert !user.new_record?
    assert !user.node.new_record?
    assert_equal sites_id(:zena), user.node.site_id
  end

  def test_create_with_auto_publish
    Site.connection.execute "UPDATE sites SET auto_publish = #{Zena::Db::TRUE} WHERE id = #{sites_id(:zena)}"
    login(:lion)
    user = secure!(User) { User.create('status'=>'50', 'group_ids'=>[''], 'lang'=>'fr', 'time_zone'=>'Europe/Zurich', 'node_attributes' => {'first_name'=>'William', 'name'=>'Shakespeare'}, 'login'=>'bob', 'password'=>'jsahjks894') }
    assert !user.new_record?
    assert !user.node.new_record?
    assert_equal sites_id(:zena), user.node.site_id
  end

  def test_create_admin_with_groups
    login(:lion)
    user = secure(User) { User.new("login"=>"john", "password"=>"isjjna78a9h", "group_ids" => [groups_id(:admin)]) }
    assert user.save
    user = secure(User) { User.find(user[:id])}
    assert_equal 3, user.groups.size
  end

  def test_update_keep_password
    login(:tiger)
    user = secure!(User) { users(:tiger) }
    pass = user[:password]
    assert pass != "", "Password not empty"
    assert user.update_attributes(:login=>'bigme', :password=>'')
    assert_equal 'bigme', user.login
    assert_equal pass, user[:password]
  end

  def test_only_self_or_admin_can_update
    login(:tiger)
    user = secure!(User) { users(:ant) }
    user.lang = 'de'
    assert !user.save
    assert user.errors[:base] #.any?
    user = secure!(User) { users(:tiger) }
    user.lang = 'de'
    assert user.save
    assert_equal 'de', user.lang
  end

  def test_only_admin_can_create
    login(:tiger)
    user = secure!(User) { User.create(:login=>'joe', :password=>'whatever') }
    assert user.new_record?
    assert user.errors[:base] #.any?
    login(:lion)
    user = secure!(User) { User.create(:login=>'joe', :password=>'whatever') }
    assert !user.new_record?
  end

  def test_cannot_remove_self_from_admin_status
    login(:lion)
    user = secure!(User) { users(:lion) }
    assert !user.update_attributes(:status => User::Status[:user])
    assert_equal 'You do not have the rights to do this.', user.errors[:status]
    user = secure!(User) { users(:lion) }
    assert user.update_attributes('status' => User::Status[:admin].to_s, 'time_zone' => 'Europe/Berlin')
  end

  def test_can_update_pass_admin_status
    login(:lion)
    user = users(:ant)
    assert user.update_attributes(:status => User::Status[:admin])
    user.reload
    assert_equal User::Status[:admin], user.status
    assert user.is_admin?
    login(:ant) # admin
    assert visitor.is_admin?
    user = users(:lion)
    assert user.update_attributes(:status => User::Status[:user])
    user.reload
    assert_equal User::Status[:user], user.status
    assert !user.is_admin?
  end

  def test_empty_password
    login(:lion)
    bob = secure!(User) { User.new }
    bob.login = 'bob'
    bob.save
    assert ! bob.save
    assert bob.errors[:password] #.any?
  end

  def test_update_public
    login(:lion)
    pub = secure!(User) { users(:anon) }
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
    # status dgroup = managers
    node = nodes(:status)
    assert_equal groups_id(:managers), node.dgroup_id
    # tiger in managers
    to_publish = visitor.comments_to_publish
    assert_equal 1, to_publish.size
    assert_equal 'Nice site', to_publish[0][:title]

    # ant not in managers
    login(:ant)
    to_publish = visitor.comments_to_publish
    assert_nil to_publish
  end

  def test_is_admin
    login(:ant)
    user = secure!(User) { users(:lion) }
    assert user.is_admin?
  end

  def test_group_ids
    login(:ant)
    user = secure!(User) { users(:tiger) }
    assert_equal [groups_id(:managers), groups_id(:public), groups_id(:workers)], user.group_ids
    user = secure!(User) { users(:lion) }
    assert_equal [groups_id(:admin), groups_id(:managers), groups_id(:public), groups_id(:workers)], user.group_ids
  end

  def test_status_name
    login(:lion)
    user = secure!(User) { users(:lion) }
    assert_equal "admin", user.status_name
    user = secure!(User) { users(:ant) }
    assert_equal "user", user.status_name
    user = secure!(User) { users(:anon) }
    assert_equal "moderated", user.status_name
  end

  def test_invalid_time_zone
    login(:lion)
    user = secure!(User) { User.create("login"=>"john", "password"=>"isjjna78a9h", 'time_zone' => 'Zurich') }
    assert user.new_record?
    assert_not_nil user.errors['time_zone']

    user = secure!(User) { User.create("login"=>"john", "password"=>"isjjna78a9h", 'time_zone' => 'Mexico/General') }
    assert !user.new_record?

    user = secure!(User) { User.create("login"=>"jim", "password"=>"isjjna78a9h", 'time_zone' => '') }
    assert !user.new_record?
    assert_nil user[:time_zone]
  end

  def test_new_defaults
    login(:lion)
    User.connection.execute "UPDATE users SET lang='fr' WHERE id = #{users_id(:anon)}"
    User.connection.execute "UPDATE users SET time_zone = 'Europe/Berlin' WHERE id = #{users_id(:anon)}"

    user = secure!(User) { User.create("login"=>"john", "password"=>"isjjna78a9h") }
    assert !user.new_record?
    assert_equal 'fr', user.lang
    assert_equal 'Europe/Berlin', user[:time_zone]
    assert_equal User::Status[:moderated], user.status
  end

  def test_tz
    login(:ant)
    assert_equal TZInfo::Timezone.get('Europe/Zurich'), visitor.tz
    login(:lion)
    assert_equal TZInfo::Timezone.get('UTC'), visitor.tz
  end

  def test_redactions
    login(:tiger)
    assert_equal ['super ouverture'], visitor.redactions.map {|r| r.node.title}
    node = secure(Page) { Page.create(:title => 'hello', :parent_id => nodes_id(:projects)) }
    node.propose
    assert_equal ['hello'], visitor.to_publish.map {|r| r.node.title}
    assert_equal ['hello'], visitor.proposed.map {|r| r.node.title}

    login(:lion)
    assert_equal ['hello'], visitor.to_publish.map {|r| r.node.title}
  end

  context 'Creating a new user' do
    setup do
      login(:lion)
    end

    context 'with new' do
      should 'accept a password attribute' do
        user = nil
        assert_nothing_raised { user = User.new('name' => 'R2D2', 'password' => 'Artoo') }
        assert_equal Zena::CryptoProvider::Initial.encrypt('Artoo'), user.crypted_password
      end
    end

    context 'with new_no_defaults' do
      should 'accept a password attribute' do
        user = nil
        assert_nothing_raised { user = User.new_no_defaults('name' => 'R2D2', 'password' => 'Artoo') }
        assert_equal Zena::CryptoProvider::Initial.encrypt('Artoo'), user.crypted_password
      end
    end
  end

  context 'A user not in the api_group' do
    subject do
      users(:ant)
    end

    should 'not be authorized access to API' do
      assert !subject.api_authorized?
    end
  end # A user not in the api_group

  context 'A user in the api_group' do
    subject do
      users(:tiger)
    end

    should 'be authorized access to API' do
      assert subject.api_authorized?
    end
  end # A user in the api_group
end
