require 'test_helper'
require 'fixtures'

class DeclarationDirty < Test::Unit::TestCase

  context 'When setting a property' do
    Pirate = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property
      property.float 'boat'
      property.string 'bird_name'
    end

    subject { Pirate.create }

    context 'without a property column' do
      setup do
        assert !subject.update_attributes('honest' => 'man')
      end

      should 'render object invalid' do
        assert subject.invalid?
      end

      should 'set an error message on the property' do
        assert_contains subject.errors.full_messages, 'Honest property is not declared'
        assert_equal subject.errors['honest'], 'property is not declared'
      end
    end

    context 'from the wrong data type' do
      setup do
        subject.update_attributes('boat' => Time.now, 'bird_name' => 1337)
      end

      should 'cast the data type' do
        assert subject.valid?
        assert_kind_of Float, subject.prop['boat']
        assert_kind_of String, subject.prop['bird_name']
        assert_equal '1337', subject.prop['bird_name']
      end
    end

    context 'to a blank value' do
      subject { Pirate.create('bird_name' => 'Rainbow Lorikeet') }

      should 'accept nil' do
        assert subject.update_attributes('bird_name' => nil)
      end

      should 'accept empty string' do
        assert subject.update_attributes('bird_name' => '')
      end

      should 'clear property if there is no default' do
        subject.update_attributes('bird_name' => '')
        assert_nil subject.properties['bird_name']
      end
    end

  end # When setting a property

  context 'On a class with default property values' do
    Cat = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property::Attribute
      property do |p|
        p.string 'eat', :default => 'mouse'
        p.string 'name'
      end
    end

    should 'insert default values' do
      subject = Cat.create
      subject.reload
      assert_equal 'mouse', subject.prop['eat']
    end

    should 'insert accept other values' do
      subject = Cat.create('eat' => 'birds')
      subject.reload
      assert_equal 'birds', subject.prop['eat']
    end

    should 'revert to default value when set to empty string' do
      subject = Cat.create('eat' => 'birds')
      subject.update_attributes('eat' => '')
      assert_equal 'mouse', subject.prop['eat']
    end

    should 'revert to default value when set to nil' do
      subject = Cat.create('eat' => 'birds')
      subject.update_attributes('eat' => nil)
      assert_equal 'mouse', subject.prop['eat']
    end
  end
end