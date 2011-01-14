require 'test_helper'

class RoleTest < Zena::Unit::TestCase

  context 'Finding a Role' do
    subject do
      roles(:Task)
    end

    context 'with an anonymous visitor' do
      setup do
        login(:anon)
      end

      should 'find role' do
        assert subject
      end
    end # An anonymous visitor

    context 'with a visitor that is not an admin' do
      setup do
        login(:tiger)
      end

      should 'find role' do
        assert subject
      end
    end # A visitor that is not an admin

    context 'with an admin visitor' do
      setup do
        login(:lion)
      end

      should 'find role' do
        assert subject
      end
    end # with an admin visitor
  end # Finding a Role


  context 'Creating a new Role' do
    subject do
      Role.create('name' => 'WriteTests')
    end

    context 'with an anonymous visitor' do
      setup do
        login(:anon)
      end

      should 'not be allowed' do
        assert_difference('Role.count', 0) do
          subject
        end
      end
    end # An anonymous visitor

    context 'with a visitor that is not an admin' do
      setup do
        login(:tiger)
      end

      should 'not be allowed' do
        assert_difference('Role.count', 0) do
          subject
        end
      end
    end # A visitor that is not an admin

    context 'with an admin visitor' do
      setup do
        login(:lion)
      end

      should 'create a new roles' do
        assert_difference('Role.count', 1) do
          subject
        end
      end
    end # with an admin visitor
  end # Creating a new Role

  context 'Updating a Role' do
    subject do
      roles(:Task)
    end

    context 'with an anonymous visitor' do
      setup do
        login(:anon)
      end

      should 'not be allowed' do
        assert !subject.update_attributes('name' => 'Paper')
      end
    end # An anonymous visitor

    context 'with a visitor that is not an admin' do
      setup do
        login(:tiger)
      end

      should 'not be allowed' do
        assert !subject.update_attributes('name' => 'Paper')
      end
    end # A visitor that is not an admin

    context 'with an admin visitor' do
      setup do
        login(:lion)
      end

      should 'update role' do
        assert subject.update_attributes('name' => 'Paper')
        assert_equal 'Paper', roles(:Task).name
      end
    end # with an admin visitor
  end # Creating a new Role
  
  context 'with a role' do
    subject do
      roles(:Original)
    end

    should 'return all defined safe columns' do
      assert_equal %w{origin tz weight}, subject.defined_safe_columns.map(&:name)
    end
  end # with a virtual class
  # Indexed columns in role tested in NodeTest
end
