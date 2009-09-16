require 'test_helper'

class NestedAttributesAliasViewTest < Zena::View::TestCase
  include Zena::Use::NestedAttributesAlias::ViewMethods

  class HashAsMethods < Hash
    def initialize(hash = {})
      replace(hash)
    end

    def method_missing(method, *args)
      if method.to_s =~ /^(.*)=$/
        self[$1] = args.first
      else
        self[method.to_s]
      end
    end
  end

  class Foo < ActiveRecord::Base
    set_table_name 'nodes'
    include Zena::Use::NestedAttributesAlias::ModelMethods

    nested_attributes_alias %r{^v_(.+)}      => 'version'
    nested_attributes_alias %r{^c_(.+)}      => 'version.content'
    nested_attributes_alias %r{^d_(.+)$}     => 'version.dyn'
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

    def link
      @link ||= returning(HashAsMethods.new) do |l|
        l.friend = HashAsMethods.new('other_id' => 1234)
      end
    end

    def version
      @version ||= returning(HashAsMethods.new('title' => 'version title')) do |v|
        v.content = HashAsMethods.new('width' => 33)
      end
    end

  end

  def setup
    @foo = Foo.new
  end

  def pending
    print 'P'
  end

  def test_text_field_should_find_value
    assert_css 'input#foo_v_title[@name="foo[v_title]"][@value="version title"]', text_field('foo', 'v_title')
  end

  def test_text_field_should_find_value_through_proc
    assert_css 'input#foo_friend_id[@name="foo[friend_id]"][@value="1234"]', text_field('foo', 'friend_id')
  end

  def test_text_field_should_find_value_deeply_nested
    assert_css 'input#foo_c_width[@name="foo[c_width]"][@value="33"]', text_field('foo', 'c_width')
  end

  def test_password_field_should_find_value
    pending
  end

  def test_hidden_field_should_find_value
    pending
  end

  def test_file_field_should_find_value
    pending
  end

  def test_text_area_should_find_value
    pending
  end

  def test_check_box_should_find_value
    pending
  end

  def test_radio_button_should_find_value
    pending
  end
end
