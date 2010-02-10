require 'test_helper'
require 'fixtures'

class TestAttribute < Test::Unit::TestCase

  context 'Module inclusion' do
    should 'include Serialization::Marshal' do
      assert Version.include?(Dynamo::Serialization::Marshal)
    end

    should 'include Dirty' do
      assert Version.include?(Dynamo::Dirty)
    end

    should 'include Declaration' do
      assert Version.include?(Dynamo::Declaration)
    end
  end


  context 'Write dynamic attributes with dynamo=' do
    setup do
      @version = Version.new
      @version.dynamo={'foo'=>'bar'}
    end

    subject { @version }

    should 'use string or symbol in key' do
      assert subject.dynamo={:foo=>'bar'}
      assert_equal Hash[:foo=>'bar'], subject.dynamo
    end

    should 'raise TypeError if new dynamic attributes is not a Hash' do
      assert_raise(TypeError) {subject.dynamo='this a string'}
    end

    should 'rewrite dynamic attributes' do
      subject.dynamo={'tic'=>'tac'}
      assert_equal 'tac', subject.dynamo['tic']
      assert_nil subject.dynamo['foo']
    end

    should 'merge new attributes with merge!' do
      subject.dynamo={'a'=>1, 'b'=>2}
      assert subject.dynamo.merge!({'b'=>'bravo', 'c'=>'charlie'})
      assert_equal 1, subject.dynamo['a']
      assert_equal 'bravo', subject.dynamo['b']
      assert_equal 'charlie', subject.dynamo['c']
    end
  end

  context 'Write attribute with dyn[]=' do
    should 'write a dynamo before creation' do
      subject = Version.new('foo'=>'bar')
      subject.dyn['foo'] = 'babar'
      assert_equal 'babar', subject.dyn['foo']
      subject.save
      assert_equal 'babar', subject.dyn['foo']
    end

    should 'write a dynamo after creation' do
      subject = Version.create('foo'=>'bar')
      subject.dyn['foo'] = 'babar'
      assert_equal 'babar', subject.dyn['foo']
      subject.save
      assert_equal 'babar', subject.dyn['foo']
    end
  end


  context 'Read dynamic attributes with dynamo' do
    setup do
      @version = Version.new
      @version.dynamo={'foo'=>'bar', :tic=>:tac}
    end

    subject { @version }

    should 'be accessible with dynamo' do
      assert_equal Hash['foo'=>'bar', :tic=>:tac], subject.dynamo
    end

    should 'be kind of Hash' do
      assert_kind_of Hash, subject.dynamo
    end

    should 'delete dynamic attribute' do
      assert_equal 'bar', subject.dynamo.delete('foo')
      assert_nil subject.dynamo['foo']
    end

  end

  context 'Update attributes' do
    setup do
      @version = Version.new
      @version.attributes={'foo'=>'bar', 'title'=>'test'}
    end

    subject { @version }

    should 'update attributes without dynamo' do
      version = Version.new
      version.attributes_without_dynamo={'title'=>'test'}
      assert_equal 'test', version.title
    end

    should 'update column attributes' do
      assert_equal 'test', subject.title
    end

    should 'filter dynamic attributes with dynamo' do
      assert_equal Hash['foo'=>'bar'], subject.dynamo
    end

    should 'updpate column attributes' do
      subject.attributes=({'comment'=>'pourquoi'})
      assert_equal 'pourquoi', subject.comment
      assert_equal 'test', subject.title
      assert_equal Hash['foo'=>'bar'], subject.dyn
    end
  end

  context 'Initialisation' do
    should 'initialize columns attributes and dynamic attributes with hash' do
      subject = Version.new('title'=>'test', 'foo' => 'bar')
      assert_equal 'test', subject.title
      assert_equal 'bar', subject.dynamo['foo']
    end

    should 'initialize columns attributes' do
      subject = Version.new('title'=>'test')
      assert_equal 'test', subject.title
      assert_nil subject.dynamo['foo']
    end

    should 'initialize dynamic attributes' do
      subject = Version.new('foo'=>'bar')
      assert_nil subject.title
      assert_equal 'bar', subject.dynamo['foo']
    end
  end

  context 'Persistence' do
    setup do
      @version = Version.new('title'=>'test', 'foo' => 'bar')
      assert @version.save
    end

    subject { @version }

    should 'save columns attributes and dynamic attributes' do
      assert_equal 'test', subject.title
      assert_equal 'bar', subject.dynamo['foo']
    end

    should 'save columns attributes' do
      version = Version.new('title'=>'test')
      assert version.save
      assert_equal 'test', version.title
      assert_nil version.dynamo['foo']
    end

    should 'save updated columns attributes' do
      subject.attributes={'comment'=>'amazing'}
      subject.save
      assert_equal 'test', subject.title
      assert_equal 'amazing', subject.comment
      assert_equal Hash['foo'=>'bar'], subject.dyn
    end

    should 'save dynamic attributes' do
      version = Version.new('foo'=>'bar')
      assert version.save
      assert_equal 'bar', version.dynamo['foo']
    end

    should 'encode dynamo with attributes' do
      assert_equal "BAh7BiIIZm9vIghiYXI=\n", subject.attributes['dynamo']
    end

    should 'create object with columns ant dynamic attributes' do
      assert version = Version.create('title'=>'test', 'foo' => 'bar')
      assert_equal 'test', version.title
      assert_equal 'bar', version.dynamo['foo']
    end

    should 'save updated dynamo' do
      subject.dynamo=({'foo'=>'barre'})
      subject.save
      assert_equal 'barre', subject.dyn['foo']
    end

    should 'destroy' do
      assert subject.destroy
      assert subject.destroyed?
      assert subject.frozen?
    end

    should 'delete' do
      assert subject.delete
      assert subject.destroyed?
      assert subject.frozen?
    end
  end

  context 'Find' do
    setup do
      @version = Version.create('title'=>'find me', 'foo' => 'bar')
    end

    should 'find by id' do
      version = Version.find(@version)
      assert_equal 'bar', version.dyn['foo']
    end
  end

  context 'Reload' do
    should 'return dynamo stored in database' do
      subject=Version.create('title'=>'find me', 'foo' => 'bar')
      subject.dyn['foo'] = 'barab'
      assert_equal 'barab', subject.dyn['foo']
      subject.dynamo!
      assert_equal 'bar', subject.dyn['foo']
    end
  end

  context 'Type cast' do
    DataType = Class.new(ActiveRecord::Base) do
      set_table_name 'dummies'
      include Dynamo::Attribute
      dynamo 'mystring', String
      dynamo 'myarray', Array
      dynamo 'myinteger', Integer
      dynamo 'myfloat', Float
      dynamo 'myhash', Hash
      dynamo 'myrange', Range
      dynamo 'mysymbol', Symbol
    end

    should 'save & read String' do
      assert subject = DataType.create('mystring'=>'some string')
      subject.reload
      assert_kind_of String, subject.dyn['mystring']
    end

    should 'save & read Array' do
      assert subject = DataType.create('myarray'=>[1,:a,'3'])
      subject.reload
      assert_kind_of Array, subject.dyn['myarray']
    end

    should 'save & read Integer' do
      assert subject = DataType.create('myinteger'=>123)
      subject.reload
      assert_kind_of Integer, subject.dyn['myinteger']
    end

    should 'save & read Float' do
      assert subject = DataType.create('myfloat'=>12.3)
      subject.reload
      assert_kind_of Float, subject.dyn['myfloat']
    end

    should 'save & read Hash' do
      assert subject = DataType.create('myhash'=>{:a=>'a', :b=>2})
      subject.reload
      assert_kind_of Hash, subject.dyn['myhash']
    end

    should 'save & read Range' do
      assert subject = DataType.create('myrange'=>(-1..-5))
      subject.reload
      assert_kind_of Range, subject.dyn['myrange']
    end

    should 'save & read Symbol' do
      assert subject = DataType.create('mysymbol'=>:abc)
      subject.reload
      assert_kind_of Symbol, subject.dyn['mysymbol']
    end


  end


end