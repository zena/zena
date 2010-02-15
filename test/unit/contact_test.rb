require 'test_helper'

class ContactTest < Zena::Unit::TestCase

  context 'On create' do

    should 'save' do
      login(:tiger)
      contact = secure!(Zena::Contact) {Zena::Contact.create('name'=>'Meyer')}
    end
  end


  context 'When looking for class' do

    setup   {@contact = Zena::Contact.new}
    subject {@contact}

    should 'return Zena::Contact with class.name' do
      assert_equal 'Zena::Contact', subject.class.name
    end

    should 'return Zena::Contact with klass' do
      assert_equal 'Zena::Contact', subject.klass
    end

    should 'return Zena::Contact with type' do
      assert_equal 'Zena::Contact', subject.type
    end
  end


  context 'When using Proprety' do
    setup {@contact = Zena::Contact.new}
    subject {@contact}

    should 'write and read first_name like AR attributes' do
      assert subject.prop['first_name'] = 'Eric'
      assert_equal 'Eric', subject.prop['first_name']
      assert_equal 'Eric', subject.first_name
    end

    should 'write and read name like AR attributes' do
      assert subject.prop['name'] = 'Meyer'
      assert_equal 'Meyer', subject.prop['name']
      assert_equal 'Meyer', subject.name
    end

    should 'create contact' do
      assert Zena::Contact.create('first_name'=>'Eric', 'name'=>'Meyer')
    end
  end

  context 'When calling user' do
    should 'return the user who created the contact' do
      login(:anon)
      contact = secure!(Node) { nodes(:tiger) }
      user = contact.user
      assert_equal users_id(:tiger), user[:id]
    end
  end

  context 'With fullname' do
    should 'return first name and name if both exist' do
      contact = Zena::Contact.new('first_name'=>'Eric', 'name'=>'Meyer')
      assert_equal 'Eric Meyer', contact.fullname
    end

    should 'return name only if first name is null' do
      contact = Zena::Contact.new('name'=>'Meyer')
      assert_equal 'Meyer', contact.fullname
    end

    should 'return firs tname only if name is null' do
      contact = Zena::Contact.new('first_name'=>'Eric')
      assert_equal 'Eric', contact.fullname
    end

  end

  context 'When calling intials' do
    setup do
      @contact = Zena::Contact.new('first_name'=>'Eric', 'name'=>'Meyer')
    end
    subject { @contact }

    should 'retrun first letters of the first_name and the name in capitals' do
      assert_equal 'EM', subject.initials
    end
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
