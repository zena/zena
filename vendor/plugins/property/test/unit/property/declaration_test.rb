require 'test_helper'
require 'fixtures'



class DeclarationDirty < Test::Unit::TestCase

  context 'Parent model' do
    should 'return parent class' do
      assert_equal 'Employee', Developer.parent_model.name
      assert_equal 'Developer', WebDeveloper.parent_model.name
    end

    should 'be nil if parents doesnt include Property' do
      assert_nil Employee.parent_model
    end

    should 'include Dynama::Attribute' do
      assert Developer.parent_model.include?(Property::Attribute)
    end
  end

  context 'Property declaration' do
    Superhero = Class.new(ActiveRecord::Base) do
      include Property::Attribute
    end

    should 'create Property::Proprety object' do
      subject = Superhero.properties('weapon', String)
      assert_kind_of PropertyDefinition, subject
      assert_equal 'weapon', subject.name
      assert_equal String, subject.data_type
    end

    should 'allow default value option' do
      subject = Superhero.properties('force', Numeric, :default=> 10)
      assert_equal 10, subject.default
    end

    should 'allow indexed option' do
      subject = Superhero.properties('name', String, :indexed=> true)
      assert subject.indexed
    end
  end

  context 'Declared property_definitions' do
    Dummy = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property::Attribute
    end

    should 'return empty Hash if no property_definitions declared' do
      assert_equal Hash[], Dummy.property_definitions
      assert_equal Hash[], Dummy.new.property_definitions_declared
    end

    should 'return list of PropertyDefinition object from class' do
      assert_kind_of Hash, Employee.property_definitions
      assert_kind_of PropertyDefinition, Employee.property_definitions[:first_name]
    end

    should 'return list of PropertyDefinition object from instance' do
      assert_kind_of Hash, Employee.new.property_definitions_declared
      assert_kind_of PropertyDefinition, Employee.new.property_definitions_declared[:first_name]
    end
  end

  context 'Property declaration missing' do
    Pirate = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property::Attribute
    end

    subject { Pirate.create(:foo=>'bar')}

    should 'render object invalid ' do
      assert subject.invalid?
    end

    should 'return message error' do
      assert_contains subject.errors.full_messages, 'Foo properties is not declared'
    end

  end

  context 'Wrong data type' do
    Duck = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property::Attribute
      properties :cack, String
    end

    subject { Duck.create(:cack=>10)}

    should 'render object invalid' do
      assert subject.invalid?
    end

    should 'return message error' do
      assert_does_not_contain subject.errors.full_messages, 'Cack properties is not declared'
      assert_contains subject.errors.full_messages, 'Cack properties has wrong data type. Received Fixnum, expected String'
    end
  end

  context 'Setting nil' do
    should 'accept new value' do
      assert false # TODO
    end
  end

  context 'Default value' do
    Cat = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property::Attribute
      properties :eat, String, :default=>'mouse'
      properties :name, String
    end

    should 'should create properties' do

    end
  end




end