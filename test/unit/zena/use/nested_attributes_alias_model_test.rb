require 'test_helper'

class NestedAttributesAliasModelTest < Test::Unit::TestCase
  class Foo
    attr_accessor :attributes
    # mock since testing outside rails
    def self.alias_method_chain(target, feature)
      aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1

      with_method, without_method = "#{aliased_target}_with_#{feature}#{punctuation}", "#{aliased_target}_without_#{feature}#{punctuation}"

      alias_method without_method, target
      alias_method target, with_method
    end

    include Zena::Use::NestedAttributesAlias::ModelMethods
    nested_attributes_alias %r{^v_(.+)}      => 'version'
    nested_attributes_alias %r{^c_(.+)}      => ['version','content']
    nested_attributes_alias %r{^(.+)\*log$}  => Proc.new {|obj, m| self.log_info(m)}
    nested_attributes_alias %r{^d_(.+)$}     => ['version','dyn']
    nested_attributes_alias %r{^(.+)_(id|status|comment)$} => Proc.new {|obj, m| obj.relation_alias(m) }

    def relation_alias(match)
      if ['friend', 'dog'].include?(match[1])
        if match[2] == 'id'
          ['link', match[1], 'other_id']
        else
          ['link', match[1], match[2]]
        end
      else
        nil
      end
    end

    def self.log_info(match)
      @@log = match[1]
      [] # match but do nothing
    end

    def self.log; @@log; end
  end

  class SubFoo < Foo
    nested_attributes_alias %r{na(.+)} => 'na'
  end


  def test_should_move_attribute_to_group
    assert_equal({'name' => 'banana', 'version_attributes' => {'title' => 'yellow'}},
                Foo.new.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana'))
  end

  def test_should_move_attribute_to_inner_group
    assert_equal({'name' => 'banana', 'version_attributes' => {'title' => 'yellow', 'content_attributes' => {'width' => 45}}},
                Foo.new.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana', 'c_width' => 45))
  end

  def test_should_be_able_to_parse_multiple_dynamic_attributes
    assert_equal({'name'=>'banana', 'version_attributes' => {'dyn_attributes' => {'foo' => 32, 'bar' => 'bara'}}},
                Foo.new.resolve_attributes_alias('d_foo' => 32, 'name' => 'banana', 'd_bar' => 'bara'))
  end

  def test_should_execute_proc_to_match_alias
    assert_equal({'name'=>'banana', 'link_attributes' => {'friend_attributes' => {'other_id' => 32}}},
                Foo.new.resolve_attributes_alias('friend_id' => 32, 'name' => 'banana'))
  end

  def test_suffix_and_return_empty_hash
    assert_equal({'name' => 'yoba'},
                Foo.new.resolve_attributes_alias('super*log'=>'We should not forget Superman !', 'name' => 'yoba'))
  end

  def test_produce_empty_string
    assert_equal({},
                Foo.new.resolve_attributes_alias('super*log'=>'We should not forget Superman !'))
  end

  def test_many_options
    assert_equal({'name' => 'banana',
      'version_attributes' => {'content_attributes' => {'width' => 45}, 'title' => 'yellow', 'text' => 'home'}},
                Foo.new.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana', 'c_width' => 45,
                'version_attributes' => {'text' => 'home'}, 'new*log' => 'bazar'))
  end

  def test_subclass_should_inherit_properly
    assert_equal({'name' => 'Joe'},
                Foo.new.resolve_attributes_alias('name' => 'Joe'))
    assert_equal({'na_attributes' => {'me' => 'Joe'}, 'version_attributes' => {'title' => 'Plumber'}},
                SubFoo.new.resolve_attributes_alias('name' => 'Joe', 'v_title' => 'Plumber'))
  end

  def test_set_attributes
    f = Foo.new
    f.attributes = {'name' => 'Joe', 'v_title' => 'Plumber'}
    assert_equal({'name'=>'Joe', 'version_attributes'=>{'title'=>'Plumber'}}, f.attributes)
  end

  def test_convert_keys_to_strings
    assert_equal({'name'=>'one',
     'version_attributes'=>{'title'=>{'one'=>'Joe', 'two'=>'Plumber'}}},
                Foo.new.resolve_attributes_alias(:name => 'one', :v_title => {:one => 'Joe', :two => 'Plumber'}))
  end

end
