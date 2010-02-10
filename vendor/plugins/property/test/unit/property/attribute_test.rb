require 'test_helper'
require 'fixtures'

class TestAttribute < Test::Unit::TestCase

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
    setup do
      @version = Version.new
      @version.properties = {'foo'=>'bar'}
    end

    context 'with properties=' do
      should 'merge hash in current content' do
        @version.properties = {'other' => 'value'}
        assert_equal Hash['foo' => 'bar', 'other' => 'value'], @version.properties
      end

      should 'replace current values' do
        @version.properties = {'foo' => 'baz'}
        assert_equal Hash['foo' => 'baz'], @version.properties
      end

      should 'raise TypeError if new dynamic attributes is not a Hash' do
        assert_raise(TypeError) { @version.properties = 'this a string' }
      end
    end

    should 'with merge! should merge new attributes' do
      @version.properties.merge!({'b'=>'bravo', 'c'=>'charlie'})
      assert_equal Hash['foo' => 'bar', 'b' => 'bravo', 'c' => 'charlie'], @version.properties
    end
  end

  context 'When writing attributes with hash access' do
    setup do
      @version = Version.new('foo'=>'bar')
      @version.properties['foo'] = 'babar'
    end

    should 'write a property into properties' do
      assert_equal Hash['foo' => 'babar'], @version.properties
    end

    should 'save property in properties' do
      @version.save
      version = Version.find(@version.id)
      assert_equal Hash['foo' => 'babar'], version.properties
    end
  end


  context 'Read dynamic attributes with properties' do
    setup do
      @version = Version.new
      @version.properties={'foo'=>'bar', :tic=>:tac}
    end

    should 'be accessible with properties' do
      assert_equal Hash['foo'=>'bar', :tic=>:tac], @version.properties
    end

    should 'be kind of Hash' do
      assert_kind_of Hash, @version.properties
    end

    should 'delete dynamic attribute' do
      assert_equal 'bar', @version.properties.delete('foo')
      assert_nil @version.properties['foo']
    end

  end

  context 'Setting attributes' do
    setup do
      @version = Version.new
      @version.attributes = {'foo'=>'bar', 'title'=>'test', 'backup' => 'please'}
    end

    should 'set rails attributes' do
      assert_equal 'test', @version.title
    end

    should 'set properties' do
      assert_equal Hash['foo'=>'bar'], @version.properties
    end

    should 'call native methods' do
      assert_equal 'please', @version.backup
    end
  end

  context 'Initializing an object' do
    setup do
      @version = Version.new('foo'=>'bar', 'title'=>'test', 'backup' => 'please')
    end

    should 'set rails attributes' do
      assert_equal 'test', @version.title
    end

    should 'set properties' do
      assert_equal Hash['foo'=>'bar'], @version.properties
    end

    should 'call native methods' do
      assert_equal 'please', @version.backup
    end
  end

  context 'Updating attributes' do
    setup do
      version = Version.create('title' => 'first', 'tic' => 'tac')
      @version = Version.find(version.id)
      assert @version.update_attributes('foo'=>'bar', 'title'=>'test', 'backup' => 'please')
    end

    should 'update rails attributes' do
      assert_equal 'test', @version.title
    end

    should 'update properties' do
      assert_equal Hash['tic' => 'tac', 'foo'=>'bar'], @version.properties
    end

    should 'call native methods' do
      assert_equal 'please', @version.backup
    end
  end

  context 'Saving attributes' do
    setup do
      version  = Version.create('title'=>'test', 'foo' => 'bar', 'backup' => 'please')
      @version = Version.find(version.id)
    end

    should 'save rails attributes' do
      assert_equal 'test', @version.title
    end

    should 'save properties' do
      assert_equal 'bar', @version.prop['foo']
    end

    should 'destroy' do
      assert @version.destroy
      assert @version.frozen?
    end

    should 'delete' do
      assert @version.delete
      assert @version.frozen?
    end
  end

  context 'Saving empty attributes' do
    setup do
      @version = Version.new('foo' => 'bar')
      @version.prop.delete('foo')
      @version.save
    end

    should 'save nil in database' do
      assert_nil @version['properties']
    end

    should 'save nil when last property is removed' do
      @version = Version.create('foo' => 'bar', 'tic' => 'tac')
      @version.attributes = {'foo' => nil}
      @version.update_attributes('foo' => nil)
      assert_equal ['tic'], @version.properties.keys
      @version.properties.delete('tic')
      @version.save
      assert_nil @version['properties']
    end
  end

  context 'Saving without changes to properties' do
    setup do
      version = Version.create('title' => 'test', 'foo' => 'bar')
      @version = Version.find(version.id)
      @version.update_attributes('title' => 'updated')
    end

    should 'not alter properties' do
      assert_equal Hash['foo' => 'bar'], @version.properties
    end
  end

  context 'Find' do
    setup do
      @version = Version.create('title'=>'find me', 'foo' => 'bar')
    end

    should 'find by id' do
      version = Version.find(@version)
      assert_equal 'bar', version.prop['foo']
    end
  end

  context 'A modified version receiving :reload_properties' do
    should 'return properties stored in database' do
      @version = Version.create('title'=>'find me', 'foo' => 'bar')
      @version.prop['foo'] = 'Babar'
      assert_equal 'Babar', @version.prop['foo']
      @version.reload_properties!
      assert_equal 'bar', @version.prop['foo']
    end
  end

  context 'Type cast' do
    DataType = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Property
      property 'mystring', String
      property 'myarray', Array
      property 'myinteger', Integer
      property 'myfloat', Float
      property 'myhash', Hash

      # Range and Symbol are not supported by JSON and are hard to read/write
      # from the web.
      # property 'myrange', Range
      # property 'mysymbol', Symbol
    end

    should 'save and read String' do
      assert subject = DataType.create('mystring' => 'some string')
      subject.reload
      assert_kind_of String, subject.prop['mystring']
    end

    should 'save and read Array' do
      assert subject = DataType.create('myarray' => [1,:a,'3'])
      subject.reload
      assert_kind_of Array, subject.prop['myarray']
    end

    should 'save and read Integer' do
      assert subject = DataType.create('myinteger' => 123)
      subject.reload
      assert_kind_of Integer, subject.prop['myinteger']
    end

    should 'save and read Float' do
      assert subject = DataType.create('myfloat' => 12.3)
      subject.reload
      assert_kind_of Float, subject.prop['myfloat']
    end

    should 'save and read Hash' do
      assert subject = DataType.create('myhash' => {:a=>'a', :b=>2})
      subject.reload
      assert_kind_of Hash, subject.prop['myhash']
    end

    context 'from a String' do
      should 'parse integer values' do
        assert subject = DataType.create('myinteger' => '123')
        subject.reload
        assert_kind_of Integer, subject.prop['myinteger']
      end

      should 'save and read Float' do
        assert subject = DataType.create('myfloat' => '12.3')
        subject.reload
        assert_kind_of Float, subject.prop['myfloat']
      end

      should 'save and read Hash' do
        assert subject = DataType.create('myhash' => {:a=>'a', :b=>2})
        subject.reload
        assert_kind_of Hash, subject.prop['myhash']
      end
    end

    # should 'save & read Range' do
    #   assert subject = DataType.create('myrange'=>(-1..-5))
    #   subject.reload
    #   assert_kind_of Range, subject.prop['myrange']
    # end
    #
    # should 'save & read Symbol' do
    #   assert subject = DataType.create('mysymbol'=>:abc)
    #   subject.reload
    #   assert_kind_of Symbol, subject.prop['mysymbol']
    # end
  end


end