require 'test_helper'
require 'fixtures'

class DeclarationTest < Test::Unit::TestCase

  context 'A sub-class' do
    context 'from a class with property columns' do
      setup do
        @klass = Developer
      end

      should 'inherit property columsn from parent class' do
        assert_equal %w{age first_name language last_name}, @klass.property_column_names.sort
      end

      should 'not back-propagate definitions to parent' do
        assert !@klass.superclass.property_columns.include?('language')
      end

      should 'inherit current definitions from parent' do
        class ParentClass < ActiveRecord::Base
          include Property
          property.string 'name'
        end
        @klass = Class.new(ParentClass) do
          property.integer 'age'
        end
        assert_equal %w{age name}, @klass.property_column_names.sort

        ParentClass.class_eval do
          property.string 'first_name'
        end

        assert_equal %w{age first_name name}, @klass.property_column_names.sort
      end
    end
  end

  context 'Property declaration' do
    Superhero = Class.new(ActiveRecord::Base) do
      include Property
    end

    should 'create Property::Column definitions' do
      Superhero.property.string('weapon')
      assert_kind_of Property::Column, Superhero.property_columns['weapon']
    end

    should 'allow string columns' do
      Superhero.property.string('weapon')
      column = Superhero.property_columns['weapon']
      assert_equal 'weapon', column.name
      assert_equal String, column.klass
      assert_equal :string, column.type
    end

    should 'allow integer columns' do
      Superhero.property.integer('indestructible')
      column = Superhero.property_columns['indestructible']
      assert_equal 'indestructible', column.name
      assert_equal Fixnum, column.klass
      assert_equal :integer, column.type
    end

    should 'allow float columns' do
      Superhero.property.float('boat')
      column = Superhero.property_columns['boat']
      assert_equal 'boat', column.name
      assert_equal Float, column.klass
      assert_equal :float, column.type
    end

    should 'allow datetime columns' do
      Superhero.property.datetime('time_weapon')
      column = Superhero.property_columns['time_weapon']
      assert_equal 'time_weapon', column.name
      assert_equal Time, column.klass
      assert_equal :datetime, column.type
    end

    should 'allow default value option' do
      Superhero.property.integer('force', :default => 10)
      column = Superhero.property_columns['force']
      assert_equal 10, column.default
    end

    should 'allow indexed option' do
      Superhero.property.string('rolodex', :indexed => true)
      column = Superhero.property_columns['rolodex']
      assert column.indexed?
    end
  end

  context 'Property columns' do
    Dummy = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property
    end

    should 'return empty Hash if no property columsn are declared' do
      assert_equal Hash[], Dummy.property_columns
    end

    should 'return list of property columns from class' do
      assert_kind_of Hash, Employee.property_columns
      assert_kind_of Property::Column, Employee.property_columns['first_name']
    end
  end
end