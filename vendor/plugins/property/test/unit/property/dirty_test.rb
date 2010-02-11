require 'test_helper'
require 'fixtures'

class DirtyTest < Test::Unit::TestCase

  def self.should_behave_nice_after_save(bar_value)
    context 'after save' do
      setup do
        subject.save
      end

      should 'return empty hash with changes' do
        assert_equal Hash[], subject.changes
      end

      should 'return empty hash on properties.changes' do
        assert_equal Hash[], subject.properties.changes
      end

      should 'return false on properties.key_changed?' do
        assert !subject.properties.foo_changed?
      end

      should 'return current value on properties.key_was' do
        assert_equal bar_value, subject.properties.foo_was
      end
    end
  end

  context 'On a dirty object' do
    setup do
      @version = Version.create('title'=>'test', 'foo'=>'bar', 'tic'=>'tac')
    end

    subject { @version }

    context 'with changed properties' do
      setup do
        subject.properties = {'foo'=>'barre', 'tic'=>'taaac'}
      end

      should_behave_nice_after_save('barre')

      should 'return true on properties.changed?' do
        assert subject.properties.changed?
      end

      should 'return true on changed?' do
        assert subject.changed?
      end

      should 'return changed properties with :changed' do
        assert_equal %w{foo tic}, subject.changed.sort
      end

      should 'return changed properties with properties.changed' do
        assert_equal %w{foo tic}, subject.properties.changed.sort
      end

      should 'return property changes with changes' do
        assert_equal Hash['tic'=>['tac', 'taaac'], 'foo'=>['bar', 'barre']], subject.changes
      end

      should 'return property changes with properties.changes' do
        assert_equal Hash['tic'=>['tac', 'taaac'], 'foo'=>['bar', 'barre']], subject.properties.changes
      end

      should 'return true on properties.key_changed?' do
        assert subject.properties.foo_changed?
      end

      should 'return previous value on properties.key_was' do
        assert_equal 'bar', subject.properties.foo_was
      end
    end

    context 'with changed native attributes' do
      setup do
        subject.title = 'Levinas'
      end

      should_behave_nice_after_save('bar')

      should 'return false on properties.changed?' do
        assert !subject.properties.changed?
      end

      should 'return true on changed?' do
        assert subject.changed?
      end

      should 'return changed attributes with :changed' do
        assert_equal ['title'], subject.changed.sort
      end

      should 'return empty list with properties.changed' do
        assert_equal [], subject.properties.changed.sort
      end

      should 'return attributes changes with changes' do
        assert_equal Hash['title'=>['test', 'Levinas']], subject.changes
      end

      should 'return empty hash on properties.changes' do
        assert_equal Hash[], subject.properties.changes
      end

      should 'return false on properties.key_changed?' do
        assert !subject.properties.foo_changed?
      end

      should 'return current value on properties.key_was' do
        assert_equal 'bar', subject.properties.foo_was
      end
    end

    context 'with changed native attributes and properties' do
      setup do
        subject.attributes = {'title' => 'Ricœur', 'foo'=>'barre', 'tic'=>'taaac'}
      end

      should_behave_nice_after_save('barre')

      should 'return true on properties.changed?' do
        assert subject.properties.changed?
      end

      should 'return true on changed?' do
        assert subject.changed?
      end

      should 'return changed properties and attributes with :changed' do
        assert_equal %w{foo tic title}, subject.changed.sort
      end

      should 'return changed properties with properties.changed' do
        assert_equal %w{foo tic}, subject.properties.changed.sort
      end

      should 'return attributes and properties changes with changes' do
        assert_equal Hash['tic'=>['tac', 'taaac'], 'foo'=>['bar', 'barre'], 'title' => ['test', 'Ricœur']], subject.changes
      end

      should 'return property changes with properties.changes' do
        assert_equal Hash['tic'=>['tac', 'taaac'], 'foo'=>['bar', 'barre']], subject.properties.changes
      end

      should 'return true on properties.key_changed?' do
        assert subject.properties.foo_changed?
      end

      should 'return previous value on properties.key_was' do
        assert_equal 'bar', subject.properties.foo_was
      end
    end
  end
end