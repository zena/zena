require 'test/unit'
require 'zena/use/nested_attributes_alias'

class NestedAttributesAliasTest < Test::Unit::TestCase
  class Foo
    include Zena::Use::NestedAttributesAlias
    nested_attributes_alias %r{^v_(.+)}      => 'version'
    nested_attributes_alias %r{^c_(.+)}      => 'version.content'
    nested_attributes_alias %r{^(.+)\*log$}  => Proc.new {|m, v| self.log_info(m, v)}
    nested_attributes_alias %r{^d_(.+)$}     => Proc.new {|m, v| self.dynamic_attribute_alias(m, v) }
    nested_attributes_alias %r{^(.+)_(id|status|comment)$} => Proc.new {|m, v| self.relation_alias(m, v) }
    
    def self.dynamic_attribute_alias(match, value)
      {'version_attributes' => {'dyn' => {match[1] => value}}}
    end
    
    def self.relation_alias(match, value)
      if ['friend', 'dog'].include?(match[1])
        if match[2] == 'id'
          {'link' => {match[1] => {'other_id' => value}}}
        else
          {'link' => {match[1] => {match[2] => value}}}
        end
      else
        nil
      end
    end
    
    def self.log_info(match, value)
      @@log = "#{match[1]} => #{value}"
      {}
    end
    
    def self.log; @@log; end
  end
  
  class SubFoo < Foo
    nested_attributes_alias %r{na(.+)} => 'na'
  end
  
  
  def test_should_move_attribute_to_group
    assert_equal({'name' => 'banana', 'version_attributes' => {'title' => 'yellow'}},
                Foo.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana'))
  end
  
  def test_should_move_attribute_to_inner_group
    assert_equal({'name' => 'banana', 'version_attributes' => {'title' => 'yellow', 'content_attributes' => {'width' => 45}}},
                Foo.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana', 'c_width' => 45))
  end
  
  def test_should_be_able_to_parse_multiple_dynamic_attributes
    assert_equal({'name'=>'banana', 'version_attributes' => {'dyn' => {'foo' => 32, 'bar' => 'bara'}}},
                Foo.resolve_attributes_alias('d_foo' => 32, 'name' => 'banana', 'd_bar' => 'bara'))
  end
  
  def test_should_execute_proc_to_match_alias
    assert_equal({'name'=>'banana', 'link' => {'friend' => {'other_id' => 32}}},
                Foo.resolve_attributes_alias('friend_id' => 32, 'name' => 'banana'))
  end
  
  def test_suffix_and_return_empty_hash
    assert_equal({'name' => 'yoba'},
                Foo.resolve_attributes_alias('super*log'=>'We should not forget Superman !', 'name' => 'yoba'))
  end
  
  def test_produce_empty_string
    assert_equal({},
                Foo.resolve_attributes_alias('super*log'=>'We should not forget Superman !'))
    assert_equal 'super => We should not forget Superman !', Foo.log
  end
  
  def test_many_options
    assert_equal({'name' => 'banana',
      'version_attributes' => {'content_attributes' => {'width' => 45}, 'title' => 'yellow', 'text' => 'home'}},
                Foo.resolve_attributes_alias('v_title' => 'yellow', 'name' => 'banana', 'c_width' => 45,
                'version_attributes' => {'text' => 'home'}, 'new*log' => 'bazar'))
  end
  
  def test_subclass_should_inherit_properly
    assert_equal({'name' => 'Joe'},
                Foo.resolve_attributes_alias('name' => 'Joe'))
    assert_equal({'na_attributes' => {'me' => 'Joe'}, 'version_attributes' => {'title' => 'Plumber'}},
                SubFoo.resolve_attributes_alias('name' => 'Joe', 'v_title' => 'Plumber'))
  end
end
