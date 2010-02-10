require 'test_helper'
require 'fixtures'



class DeclarationDirty < Test::Unit::TestCase

  context 'Parent model' do
    should 'return parent class' do
      assert_equal 'Employee', Developer.parent_model.name
      assert_equal 'Developer', WebDeveloper.parent_model.name
    end

    should 'be nil if parents doesnt include Dynamo' do
      assert_nil Employee.parent_model
    end

    should 'include Dynama::Attribute' do
      assert Developer.parent_model.include?(Dynamo::Attribute)
    end
  end

  context 'Dynamo declaration' do
    Superhero = Class.new(ActiveRecord::Base) do
      include Dynamo::Attribute
    end

    should 'create Dynamo::Proprety object' do
      subject = Superhero.dynamo('weapon', String)
      assert_kind_of Dynamo::Property, subject
      assert_equal 'weapon', subject.name
      assert_equal String, subject.data_type
    end

    should 'allow default value option' do
      subject = Superhero.dynamo('force', Numeric, :default=> 10)
      assert_equal 10, subject.default
    end

    should 'allow indexed option' do
      subject = Superhero.dynamo('name', String, :indexed=> true)
      assert subject.indexed
    end
  end

  context 'Declared dynamos' do
    Dummy = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Dynamo::Attribute
    end

    should 'return empty Hash if no dynamos declared' do
      assert_equal Hash[], Dummy.dynamos
      assert_equal Hash[], Dummy.new.dynamos_declared
    end

    should 'return list of Dynamo::Property object from class' do
      assert_kind_of Hash, Employee.dynamos
      assert_kind_of Dynamo::Property, Employee.dynamos[:first_name]
    end

    should 'return list of Dynamo::Property object from instance' do
      assert_kind_of Hash, Employee.new.dynamos_declared
      assert_kind_of Dynamo::Property, Employee.new.dynamos_declared[:first_name]
    end
  end

  context 'Dynamo declaration missing' do
    Pirate = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Dynamo::Attribute
    end

    subject { Pirate.create(:foo=>'bar')}

    should 'render object invalid ' do
      assert subject.invalid?
    end

    should 'return message error' do
      assert_contains subject.errors.full_messages, 'Foo dynamo is not declared'
    end

  end

  context 'Wrong data type' do
    Duck = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Dynamo::Attribute
      dynamo :cack, String
    end

    subject { Duck.create(:cack=>10)}

    should 'render object invalid' do
      assert subject.invalid?
    end

    should 'return message error' do
      assert_does_not_contain subject.errors.full_messages, 'Cack dynamo is not declared'
      assert_contains subject.errors.full_messages, 'Cack dynamo has wrong data type. Received Fixnum, expected String'
    end
  end

  context 'Default value' do
    Cat = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Dynamo::Attribute
      dynamo :eat, String, :default=>'mouse'
      dynamo :name, String
    end

    should 'should create dynamo' do

    end
  end




end