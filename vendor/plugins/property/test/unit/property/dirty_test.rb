require 'test_helper'
require 'fixtures'

class TestDirty < Test::Unit::TestCase

  context 'Dirty methods' do
    setup do
      @version = Version.create({'title'=>'test', 'foo'=>'bar', 'tic'=>'tac'})
    end

    subject { @version }

    should 'check if object has changed his dynamo' do
      assert !subject.changed?
      subject.dyn=({'foo'=>'barre', 'tic'=>'taaac'})
      assert subject.changed?
    end

    should 'return a list of attributes changed' do
      subject.dyn=({'foo'=>'barre', 'tic'=>'taaac'})
      assert_equal ['foo','tic'], subject.changed
    end

    should 'check if record was changed with column attributes' do
      assert !subject.changed?
      subject.title= 'change test'
      assert subject.changed?
      assert subject.title_changed?
      assert_equal 'test', subject.title_was
    end

    should 'check if record was changed with dynamo=' do
      subject.dynamo={'foo'=>'barre'}
      assert subject.changed?
      assert subject.dynamo_changed?
    end

    should 'check if record was changed with dyn' do
      subject.dyn['foo'] = 'barre'
      assert subject.changed?
      assert subject.dynamo_changed?
    end
  end


  context 'Dynamos changes' do
    setup do
      @version = Version.create({'title'=>'test', 'foo'=>'bar', 'tic'=>'tac'})
    end

    should 'be empty when unchanges' do
      assert_equal Hash[], @version.changes
    end

    should 'be returned when updated' do
      @version.dyn=({'foo'=>'barre', 'tic'=>'taaac'})
      assert_equal Hash["foo"=>["bar", "barre"], "tic"=>["tac", "taaac"]], @version.changes
    end

    should 'be returned when deleted' do
      @version.dyn=({'foo'=>'bar'})
      assert_equal Hash["tic"=>["tac",""]], @version.changes
    end

    should 'be returned when deleted and updated' do
      @version.dyn=({'foo'=>'barre'})
      assert_equal Hash["foo"=>["bar", "barre"], "tic"=>["tac", ""]], @version.changes
    end

    should 'be returned when creating a new value' do
      @version.dyn['hi'] = 'hello'
      assert_equal Hash["hi"=>[nil, "hello"]], @version.changes
    end

    should 'be empty when assigning same value' do
      @version.dyn=({'foo'=>'bar', 'tic'=>'tac'})
      assert_equal Hash[], @version.changes
    end

    should 'show when column attribute changes' do
      @version.title = 'dirty'
      assert_equal Hash["title"=>["test", "dirty"]], @version.changes
    end

    should 'show when column and dynamic attribute changes' do
      @version.attributes=({'title'=>'dirty', 'foo'=>'barre'})
      assert_equal Hash["title"=>["test", "dirty"], "foo"=>["bar", "barre"]], @version.changes
    end
  end

end