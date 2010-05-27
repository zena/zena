require 'test_helper'

class ColumnTest < Zena::Unit::TestCase

  context 'A column' do
    setup do
      login(:lion)
    end

    subject do
      secure(Column) { columns(:Task_assigned) }
    end

    should 'return Role on role' do
      assert_kind_of Role, subject.role
    end

    should 'return kpath on kpath' do
      assert_equal 'N', subject.kpath
    end
  end # A column

  context 'Creating a column' do
    subject do
      Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'foo')
    end

    should 'create column' do
      assert_difference('Column.count', 1) do
        subject
      end
    end

    should 'set site_id' do
      subject
      assert_equal sites_id(:zena), subject.site_id
    end


    context 'with an existing name' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'origin')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'has already been taken', subject.errors[:name]
        end
      end
    end # with an existing name

    context 'with the name of a hardwire property' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'first_name')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'has already been taken in BaseContact', subject.errors[:name]
        end
      end
    end # with an existing name
  end # Creating a column

end
