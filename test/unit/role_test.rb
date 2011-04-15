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
      Role.create('name' => 'WriteTests', 'superclass' => 'Node')
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
        assert_equal 'N', subject.kpath
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

  context 'with a Role' do
    subject do
      roles(:Original)
    end

    should 'return all defined safe columns' do
      assert_equal %w{origin tz weight}, subject.defined_safe_columns.map(&:name)
    end
  end # with a Role



  context 'An admin' do
    setup do
      login(:lion)
    end

    context 'exporting a virtual class' do
      setup do
        login(:lion)
      end

      subject do
        VirtualClass['Post'].export
      end

      should 'export attributes' do
        assert_equal('VirtualClass', subject['type'])
      end

      should 'export columns' do
        assert_equal({
            'date' => {'index' => '.idx_datetime1', 'ptype' => 'datetime'},
        }, subject['columns'])
      end

      should 'export sub classes' do
      end
    end # exporting a virtual class

    context 'exporting a real class' do
      subject do
        VirtualClass['Page'].export
      end

      should 'export type as Class' do
        assert_equal('Class', subject['type'])
      end

      should 'export sub classes' do
        assert_equal(%w{Tracker Project Section Tag}, subject.keys.select{|k| k=~/\A[A-Z]/})
        assert_equal('VirtualClass', subject['Tracker']['type'])
      end

      context 'with linked roles' do
        setup do
          secure!(::Role) { ::Role.create('name' => 'Foo', 'superclass' => 'Page')}
        end

        should 'export linked roles' do
          assert_equal('Role', subject['Foo']['type'])
        end
      end # with linked roles

    end # exporting a real class

    context 'exporting a role' do
      subject do
        roles(:Original).export
      end

      should 'description' do

      end
    end # exporting a role

    context 'importing columns' do
      subject do
        roles(:Post)
      end

      should 'create properties' do
        assert_difference('Column.count', 2) do
          subject.import_columns({
            'one' => {
              'ptype' => 'string',
              'index' => 'ml_string',
            },
            'two' => {
              'ptype' => 'integer',
            },
          })
        end
      end

      should 'not create or move existing property in different role' do
        data = Zafu::OrderedHash.new
        data['one'] = {
            'ptype' => 'string',
            'index' => 'ml_string',
        }
        data['tz'] = {
            'ptype' => 'integer',
        }
        assert_difference('Column.count', 0) do
          # rollback 'one' creation
          assert_raise(Exception) do
            subject.import_columns(data)
          end
        end
      end

      should 'set property type and index' do
        subject.import_columns({
          'one' => {
            'ptype' => 'string',
            'index' => 'ml_string',
          },
          'two' => {
            'ptype' => 'integer',
          },
        })
        one = ::Column.find_by_name('one')
        two = ::Column.find_by_name('two')
        assert_equal('string', one.ptype)
        assert_equal('ml_string', one.index)
        assert_equal('integer', two.ptype)
        assert_nil(two.index)
      end

      context 'with invalid index' do
        should 'raise errors' do
          e = nil
          assert_difference('Column.count', 0) do
            e = assert_raise(ActiveRecord::RecordInvalid) do
              subject.import_columns({
                'one' => {
                  'ptype' => 'stringbar',
                },
                'two' => {
                  'ptype' => 'integer',
                  'index' => 'bad',
                },
              })
            end
          end

          r = e.record
          assert_equal "Column 'two' Validation failed: Index invalid", "#{r.class} '#{r.name}' #{e.message}"
        end
      end # with invalid index

      context 'with invalid column name' do
        should 'raise errors' do
          e = nil
          assert_difference('Column.count', 0) do
            e = assert_raise(Exception) do
              subject.import_columns({
                'one' => {
                  'ptype' => 'stringbar',
                },
                'paper' => {
                  'ptype' => 'integer',
                },
              })
            end
          end
          assert_equal "Cannot set property 'paper' in 'Post': already defined in 'Letter'.", e.message
        end
      end # with invalid data
    end

    context 'importing roles' do
      subject do
        { 'Node' => {
            'Foo' => {
              'type'       => 'Role',
              'columns'    => {
                'foo' => {'index' => '',       'ptype' => 'integer'},
                'bar' => {'index' => '',       'ptype' => 'string'},
                'baz' => {'index' => 'string', 'ptype' => 'string'},
              },
            },
          },
        }
      end

      should 'create roles' do
        assert_difference('Role.count', 1) do
          ::Role.import(subject)
        end
        role = Role.find_by_name 'Foo'
        assert_equal 'N', role.kpath
      end

      should 'create columns' do
        assert_difference('Column.count', 3) do
          ::Role.import(subject)
        end
      end
    end # importing roles

    context 'importing virtual classes' do
      setup do
        VirtualClass.expire_cache!
      end

      subject do
        { 'Node' => {
            'Note' => {
              'Foo' => {
                'type'       => 'VirtualClass',
                'idx_scope'  => "{'reference' => 'references', 'contact' => 'project'}",
                'columns'    => {
                  'foo' => {'index' => '',       'ptype' => 'integer'},
                  'bar' => {'index' => '',       'ptype' => 'string'},
                  'baz' => {'index' => 'string', 'ptype' => 'string'},
                },
              },
            },
          },
        }
      end

      should 'create virtual class' do
        assert_difference('VirtualClass.count', 1) do
          ::Role.import(subject)
        end
      end

      should 'set attributes' do
        ::Role.import(subject)
        assert_equal(
          "{'reference' => 'references', 'contact' => 'project'}",
          VirtualClass['Foo'].idx_scope
        )
        assert_equal('NNF', VirtualClass['Foo'].kpath)
      end

      should 'create columns' do
        assert_difference('Column.count', 3) do
          ::Role.import(subject)
        end
      end

      context 'with duplicate column names' do
        subject do
          { 'Node' => {
              'Foo' => {
                'type'       => 'Role',
                'columns'    => {
                  'foo' => {'ptype' => 'integer'},
                  'tz'  => {'ptype' => 'string'},
                },
              },
            },
          }
        end

        should 'raise an error' do
          assert_difference('Column.count', 0) do
            e = assert_raise(Exception) do
              ::Role.import(subject)
            end
            assert_equal "Cannot set property 'tz' in 'Foo': already defined in 'Original'.", e.message
          end
        end
      end # with duplicate column names


      context 'with bad types' do
        subject do
          { 'Node' => {
              'Note' => {
                'type' => 'Capoff',
                'Foo' => {
                  'type'       => 'Role',
                },
              },
            },
          }
        end

        should 'raise an error' do
          assert_difference('Column.count', 0) do
            e = assert_raise(Exception) do
              ::Role.import(subject)
            end
            assert_equal "Cannot create 'Note': invalid type 'Capoff'.", e.message
          end
        end
      end # with duplicate column names
    end # importing virtual classes
  end # An admin

  # Indexed columns in role tested in NodeTest

end
