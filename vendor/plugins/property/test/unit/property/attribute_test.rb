require 'test_helper'
require 'fixtures'
require 'benchmark'

class TestAttribute < Test::Unit::TestCase

  ActiveRecord::Base.default_timezone = :utc
  ENV['TZ'] = 'UTC'

  context 'When including Property' do
    should 'include Property::Attribute' do
      assert Version.include?(Property::Attribute)
    end

    should 'include Property::Serialization::JSON' do
      assert Version.include?(Property::Serialization::JSON)
    end

    should 'include Property::Dirty' do
      assert Version.include?(Property::Dirty)
    end

    should 'include Property::Declaration' do
      assert Version.include?(Property::Declaration)
    end
  end

  context 'When defining new properties' do
    should 'not allow symbols as keys' do
      assert_raise(ArgumentError) do
        Class.new(ActiveRecord::Base) do
          include Property
          property :foo, String
        end
      end
    end
  end

  context 'When writing properties' do
    subject { Version.new }

    setup do
      subject.properties = {'foo'=>'bar'}
    end

    context 'with properties=' do
      should 'merge hash in current content' do
        subject.properties = {'other' => 'value'}
        assert_equal Hash['foo' => 'bar', 'other' => 'value'], subject.properties
      end

      should 'replace current values' do
        subject.properties = {'foo' => 'baz'}
        assert_equal Hash['foo' => 'baz'], subject.properties
      end

      should 'raise TypeError if new attributes is not a Hash' do
        assert_raise(TypeError) { subject.properties = 'this a string' }
      end
    end

    should 'with merge! should merge new attributes' do
      subject.properties.merge!({'b'=>'bravo', 'c'=>'charlie'})
      assert_equal Hash['foo' => 'bar', 'b' => 'bravo', 'c' => 'charlie'], subject.properties
    end
  end

  context 'When writing attributes with hash access' do
    subject { Version.new('foo' => 'bar') }

    setup do
      subject.properties['foo'] = 'babar'
    end

    should 'write a property into properties' do
      assert_equal Hash['foo' => 'babar'], subject.properties
    end

    should 'save property in properties' do
      subject.save
      version = Version.find(subject.id)
      assert_equal Hash['foo' => 'babar'], version.properties
    end
  end


  context 'The properties of an object' do
    subject { Version.new }

    setup do
      subject.properties={'foo'=>'bar', :tic=>:tac}
    end

    should 'be accessible with :properties method' do
      assert_equal Hash['foo'=>'bar', :tic=>:tac], subject.properties
    end

    should 'be a kind of Hash' do
      assert_kind_of Hash, subject.properties
    end

    should 'respond to delete' do
      assert_equal 'bar', subject.properties.delete('foo')
      assert_nil subject.properties['foo']
    end

  end

  context 'Setting attributes' do
    subject { Version.new }

    setup do
      subject.attributes = {'foo'=>'bar', 'title'=>'test', 'backup' => 'please'}
    end

    should 'set rails attributes' do
      assert_equal 'test', subject.title
    end

    should 'set properties' do
      assert_equal Hash['foo'=>'bar'], subject.properties
    end

    should 'call native methods' do
      assert_equal 'please', subject.backup
    end
  end

  context 'Initializing an object' do
    subject { Version.new('foo'=>'bar', 'title'=>'test', 'backup' => 'please') }

    should 'set rails attributes' do
      assert_equal 'test', subject.title
    end

    should 'set properties' do
      assert_equal Hash['foo'=>'bar'], subject.properties
    end

    should 'call native methods' do
      assert_equal 'please', subject.backup
    end
  end

  context 'Updating attributes' do
    setup do
      version = Version.create('title' => 'first', 'tic' => 'tac')
      @version = Version.find(version.id)
      assert subject.update_attributes('foo'=>'bar', 'title'=>'test', 'backup' => 'please')
    end

    subject { @version }

    should 'update rails attributes' do
      assert_equal 'test', subject.title
    end

    should 'update properties' do
      assert_equal Hash['tic' => 'tac', 'foo'=>'bar'], subject.properties
    end

    should 'call native methods' do
      assert_equal 'please', subject.backup
    end
  end

  context 'Saving attributes' do
    setup do
      version  = Version.create('title'=>'test', 'foo' => 'bar', 'backup' => 'please')
      @version = Version.find(version.id)
    end

    subject { @version }

    should 'save rails attributes' do
      assert_equal 'test', subject.title
    end

    should 'save properties' do
      assert_equal 'bar', subject.prop['foo']
    end

    should 'destroy' do
      assert subject.destroy
      assert subject.frozen?
    end

    should 'delete' do
      assert subject.delete
      assert subject.frozen?
    end
  end

  context 'Saving empty attributes' do
    subject { Version.new('foo' => 'bar') }

    setup do
      subject.prop.delete('foo')
      subject.save
    end

    should 'save nil in database' do
      assert_nil subject['properties']
    end

    should 'save nil when last property is removed' do
      subject = Version.create('foo' => 'bar', 'tic' => 'tac')
      subject.attributes = {'foo' => nil}
      subject.update_attributes('foo' => nil)
      assert_equal ['tic'], subject.properties.keys
      subject.properties.delete('tic')
      subject.save
      assert_nil subject['properties']
    end
  end

  context 'Saving without changes to properties' do
    setup do
      version = Version.create('title' => 'test', 'foo' => 'bar')
      @version = Version.find(version.id)
      subject.update_attributes('title' => 'updated')
    end

    subject { @version }

    should 'not alter properties' do
      assert_equal Hash['foo' => 'bar'], subject.properties
    end
  end

  context 'Find' do
    subject { Version.create('title'=>'find me', 'foo' => 'bar') }

    should 'find by id' do
      version = Version.find(subject)
      assert_equal 'bar', version.prop['foo']
    end
  end

  context 'A modified version receiving :reload_properties' do
    should 'return properties stored in database' do
      subject = Version.create('title'=>'find me', 'foo' => 'bar')
      subject.prop['foo'] = 'Babar'
      assert_equal 'Babar', subject.prop['foo']
      subject.reload_properties!
      assert_equal 'bar', subject.prop['foo']
    end
  end

  context 'Type cast' do
    DataType = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property
      property do |p|
        p.string 'mystring'
        p.integer 'myinteger'
        p.float 'myfloat'
        p.datetime 'mytime'
      end
    end

    should 'save and read String' do
      subject = DataType.create('mystring' => 'some string')
      subject.reload
      assert_kind_of String, subject.prop['mystring']
    end

    should 'save and read Integer' do
      subject = DataType.create('myinteger' => 123)
      subject.reload
      assert_kind_of Integer, subject.prop['myinteger']
    end

    should 'save and read Float' do
      subject = DataType.create('myfloat' => 12.3)
      subject.reload
      assert_kind_of Float, subject.prop['myfloat']
    end

    should 'save and read Time' do
      subject = DataType.create('mytime' => Time.new)
      subject.reload
      assert_kind_of Time, subject.prop['mytime']
    end

    context 'from a String' do
      should 'parse integer values' do
        subject = DataType.create('myinteger' => '123')
        subject.reload
        assert_kind_of Integer, subject.prop['myinteger']
        assert_equal 123, subject.prop['myinteger']
      end

      should 'parse float values' do
        subject = DataType.create('myfloat' => '12.3')
        subject.reload
        assert_kind_of Float, subject.prop['myfloat']
        assert_equal 12.3, subject.prop['myfloat']
      end

      should 'parse time values' do
        subject = DataType.create('mytime' => '2010-02-10 21:21')
        subject.reload
        assert_kind_of Time, subject.prop['mytime']
        assert_equal Time.utc(2010,02,10,21,21), subject.prop['mytime']
      end

      context 'in the model' do
        should 'parse integer values' do
          subject = DataType.new
          subject.prop['myinteger'] = '123'
          assert_kind_of Integer, subject.prop['myinteger']
          assert_equal 123, subject.prop['myinteger']
        end

        should 'parse float values' do
          subject = DataType.new
          subject.prop['myfloat'] = '12.3'
          assert_kind_of Float, subject.prop['myfloat']
          assert_equal 12.3, subject.prop['myfloat']
        end

        should 'parse time values' do
          subject = DataType.new
          subject.prop['mytime'] = '2010-02-10 21:21'
          assert_kind_of Time, subject.prop['mytime']
          assert_equal Time.utc(2010,02,10,21,21), subject.prop['mytime']
        end
      end
    end
  end


end