require 'test_helper'

class BaseContactTest < Zena::Unit::TestCase

  context 'On initialize' do
    setup do
      login(:tiger)
    end
    subject do
      secure!(BaseContact) {BaseContact.new('name' => 'Meyer', :parent_id => nodes_id(:zena))}
    end

    should 'have a parent' do
      assert_equal nodes_id(:zena), subject.parent(false).id
    end

    should 'have a parent with fullpath' do
      assert_equal '', subject.parent(false).fullpath
    end
  end

  context 'A logged in user' do
    setup do
      login(:tiger)
    end

    context 'creating a contact by title' do
      subject do
        secure!(BaseContact) { BaseContact.create('title' => 'Eric Meyer', :parent_id => nodes_id(:zena))}
      end

      should 'extract name and first_name' do
        assert_equal 'Meyer', subject.name
      end

      should 'extract first_name' do
        assert_equal 'Eric', subject.first_name
      end
    end # creating a contact by title

    context 'creating a contact' do
      subject do
        secure!(BaseContact) { BaseContact.create(:name => 'Meyer', :first_name => 'Eric', :parent_id => nodes_id(:zena)) }
      end

      should 'save record' do
        assert_difference('Node.count', 1) do
          assert !subject.new_record?
        end
      end

      should 'create a first version' do
        assert_difference('Version.count', 1) do
          assert !subject.version.new_record?
        end
      end

      should 'be clean after save' do
        assert !subject.changed?
        assert !subject.version.changed?
      end

      should 'write and read first_name like AR attributes' do
        assert subject.prop['first_name'] = 'Bertrand'
        assert_equal 'Bertrand', subject.prop['first_name']
        assert_equal 'Bertrand', subject.first_name
      end

      should 'write and read name like AR attributes' do
        assert subject.prop['name'] = 'Hoffer'
        assert_equal 'Hoffer', subject.prop['name']
        assert_equal 'Hoffer', subject.name
      end

      should 'build node_name from fullname' do
        assert_equal 'EricMeyer', subject.node_name
      end
    end

    context 'creating a contact without parent_id' do
      subject do
        secure!(BaseContact) { BaseContact.create('name' => 'Meyer') }
      end

      should 'not save' do
        assert subject.new_record?
      end
    end # creating a contact without parent_id
  end # A logged in user

  context 'A contact' do
    subject do
      secure(Node) { nodes(:tiger) }
    end

    context 'receiving initials' do
      should ' first letters of the first_name and the name in capitals' do
        assert_equal 'PTS', subject.initials
      end
    end # receiving initials
  end # A contact

  context 'Updating a contact' do
    setup do
      login(:tiger)
    end

    subject do
      secure(Node) { nodes(:ant) }
    end

    context 'with a new name' do
      setup do
        assert subject.update_attributes('name' => 'Meyer')
      end

      should 'save changes' do
        subject.reload
        assert_equal 'Meyer', subject.name
      end

      should 'rebuild title if title was in sync' do
        assert_equal 'Solenopsis Meyer', subject.title
      end

      context 'with a title not in sync' do
        subject do
          secure(Node) { nodes(:tiger) }
        end

        should 'not rebuild title' do
          assert_equal 'Meyer', subject.name
          assert_equal 'Tiger', subject.title
        end
      end
    end

    context 'with a new first_name' do
      setup do
        subject.update_attributes('first_name' => 'Eric')
      end

      should 'save changes' do
        subject.reload
        assert_equal 'Eric', subject.first_name
      end

      should 'rebuild title if title was in sync' do
        assert_equal 'Eric Invicta', subject.title
      end

      context 'with a title not in sync' do
        subject do
          secure(Node) { nodes(:tiger) }
        end

        should 'not rebuild title' do
          assert_equal 'Eric', subject.first_name
          assert_equal 'Tiger', subject.title
        end
      end
    end
  end # Updating a contact

  context 'When looking for class' do
    setup   {@contact = BaseContact.new}
    subject {@contact}

    should 'return BaseContact with class.name' do
      assert_equal 'BaseContact', subject.class.name
    end

    should 'return BaseContact with klass' do
      assert_equal 'BaseContact', subject.klass
    end

    should 'return BaseContact with type' do
      assert_equal 'BaseContact', subject.type
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
      contact = BaseContact.new('first_name' => 'Eric', 'name' => 'Meyer')
      assert_equal 'Eric Meyer', contact.fullname
    end

    should 'return name only if first name is null' do
      contact = BaseContact.new('name' => 'Meyer')
      assert_equal 'Meyer', contact.fullname
    end

    should 'return first name only if name is null' do
      contact = BaseContact.new('first_name' => 'Eric')
      assert_equal 'Eric', contact.fullname
    end

    context 'on dirty object' do
      setup do
        login(:tiger)
        @contact = secure!(BaseContact) {BaseContact.create('name' => 'Meyer', 'first_name' => 'Eric', :parent_id => nodes_id(:zena))}
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

end
