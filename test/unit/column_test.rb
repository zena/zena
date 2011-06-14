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

  context 'A date column' do
    setup do
      login(:lion)
      visitor.time_zone = 'Asia/Jakarta'
    end

    subject do
      secure(Column) { columns(:Post_date)}
    end

    should 'type_cast Time as Time' do
      assert_equal Time.utc(2011,6,6,15,58), subject.type_cast(Time.utc(2011,6,6,15,58))
    end

    should 'type_cast nil as nil' do
      assert_nil subject.type_cast(nil)
    end

    should 'type_cast empty as nil' do
      assert_nil subject.type_cast('')
    end

    should 'type_cast String as Time' do
      assert_equal Time.utc(2011,6,6,15,58), subject.type_cast("2011-06-06 22:58")
    end
  end

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
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'title')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'has already been taken in Node', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property

    context 'with the name of a method in a model' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (method defined in Node)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property

    context 'ending with _ids' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy_ids')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (cannot end with _id or _ids)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property

    context 'ending with _id' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy_id')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (cannot end with _id or _ids)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property

    context 'with an invalid ptype' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'stringlitch', :name => 'dummy')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid', subject.errors[:ptype]
        end
      end
    end # with an invalid ptype

    context 'with an invalid index' do
      subject do
        Column.create(
          :role_id => roles_id(:Task),
          :ptype   => 'string',
          :index   => 'bad',
          :name    => 'dummy'
        )
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid', subject.errors[:index]
        end
      end
    end # with an invalid index

  end # Creating a column

  context 'exporting a column' do
    setup do
      login(:lion)
    end

    subject do
      columns(:Post_date)
    end

    should 'export attributes' do
      assert_equal({
        'ptype'      => 'datetime',
        'index'      => '.idx_datetime1',
      }, subject.export)
    end
 end # exporting a role

 context 'With an attribute ending in _comment' do
   setup do
     login(:lion)
     assert Column.create(:role_id => roles_id(:Original), :ptype => 'string', :name => 'origin_comment')
   end

   teardown do
     VirtualClass.expire_cache!
   end

   should 'return safe method type' do
     assert_equal Hash[
       :nil => true,
       :class => String,
       :method => %{prop['origin_comment']}
       ], VirtualClass['Page'].safe_method_type(['origin_comment'])
   end
 end # With an attribute ending in _comment


end
