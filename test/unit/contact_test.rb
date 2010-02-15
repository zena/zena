require 'test_helper'

class ContactTest < Zena::Unit::TestCase

  context 'On create' do
    setup do
      login(:tiger)
    end

    should 'save with parent_id' do
      contact = secure!(Contact) {Contact.create('name'=>'Meyer', :parent_id => nodes_id(:zena))}
      assert !contact.new_record?
    end

    should 'not save without parent_id' do
      contact = secure!(Contact) {Contact.create('name'=>'Meyer')}
      assert contact.new_record?
    end
  end

  context 'When looking for class' do
    setup   {@contact = Contact.new}
    subject {@contact}

    should 'return Contact with class.name' do
      assert_equal 'Contact', subject.class.name
    end

    should 'return Contact with klass' do
      assert_equal 'Contact', subject.klass
    end

    should 'return Contact with type' do
      assert_equal 'Contact', subject.type
    end
  end

  context 'When using Proprety' do
    setup {@contact = Contact.new}
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
      assert Contact.create('first_name'=>'Eric', 'name'=>'Meyer')
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
      contact = Contact.new('first_name'=>'Eric', 'name'=>'Meyer')
      assert_equal 'Eric Meyer', contact.fullname
    end

    should 'return name only if first name is null' do
      contact = Contact.new('name'=>'Meyer')
      assert_equal 'Meyer', contact.fullname
    end

    should 'return firs tname only if name is null' do
      contact = Contact.new('first_name'=>'Eric')
      assert_equal 'Eric', contact.fullname
    end

    context 'on dirty object' do
      setup do
        login(:tiger)
        @contact = secure!(Contact) {Contact.create('name'=>'Meyer', 'first_name'=>'Eric', :parent_id => nodes_id(:zena))}
      end
      subject {@contact}

        context 'without changes' do
          should 'return false with fullname_changed?' do
            assert !subject.fullname_changed?
          end

          should 'actual fullname nil with fullname_was' do
            assert_equal 'Eric Meyer', subject.fullname_was
          end
        end # without changes

        context 'with changes' do
          setup do
            subject.name='Reyer'
            subject.first_name = 'Cire'
          end

          should 'return true with fullname_changed?' do
            assert subject.fullname_changed?
          end

          should 'return previous fullname with fullname was' do
            assert_equal 'Eric Meyer', subject.fullname_was
          end
        end # with changes

    end # on dirty object
  end # With fullname

  context 'When calling intials' do
    setup do
      @contact = Contact.new('first_name'=>'Eric', 'name'=>'Meyer')
    end
    subject { @contact }

    should 'retrun first letters of the first_name and the name in capitals' do
      assert_equal 'EM', subject.initials
    end
  end

  context 'When author changes' do
    setup do
      login(:tiger)
      @original = secure!(Contact) {Contact.create('name'=>'Meyer', 'first_name'=>'Eric', :parent_id => nodes_id(:zena))}
    end

    should 'save a new version of contact' do
      login(:lion)
      contact = secure!(Contact) {Contact.find(@original)}
      contact.first_name = 'Cire'
      assert contact.save
      assert_not_equal contact.id, @original.id
    end
  end
end
