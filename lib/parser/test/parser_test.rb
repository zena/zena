require 'rubygems'
require 'test/unit'
require 'yamltest'
require File.join(File.dirname(__FILE__) , '..', 'lib', 'parser')
require 'ruby-debug'
Debugger.start
unless Module.const_defined?(:ActiveRecord)
  # blank definition from active_support/core_ext/blank.rb
  class String #:nodoc:
    def blank?
      empty? || strip.empty?
    end
  end
end

class ParserModule::DummyHelper
  def find_node_by_pseudo(*args)
    args[0]
  end
end

module Zafu
  module Tags
    def r_hello
      'hello world!'
    end

    def r_only_hello
      expand_with(:only=>['hello'])
    end

    def r_only_string
      out expand_with(:only=>[:string])
    end

    def r_text
      @params[:text]
    end

    def r_repeat
      count = @params[:count] || 2
      count.to_i.times do
        out expand_with
      end
    end

    def r_set_context
      params = @params.dup
      if ignore = @params[:ignore]
        params[:ignore] = @params[:ignore].split(',').map {|e| e.strip}
      end
      expand_with(params)
    end

    def r_missing
      return '' unless check_params(:good, :night)
      "nothing missing"
    end

    def r_textarea
      res   = "<#{@html_tag}#{params_to_html(@params)}"
      @html_tag_done = true
      inner = expand_with
      if inner == ''
        res + "/>"
      else
        res + ">#{inner}"
      end
    end

    def r_test
      self.inspect
    end
  end
end

class String
  def pseudo_id(*args)
    self
  end
end

class ParserTest < Test::Unit::TestCase
  yamltest :files => [:zafu, :zafu_asset, :zafu_insight, :zazen] #, :options => {:latex => {:module => :zazen, :output => 'latex'}}
  @@test_parsers = {}
  @@test_options = {}

  @@file_list.each do |file, file_path, opts|
    mod_name = opts.delete(:module) || file
    mod_name = mod_name.to_s.split("_").first.capitalize
    @@test_parsers[file] = Parser.parser_with_rules(eval("#{mod_name}::Rules"), eval("#{mod_name}::Tags"))
    @@test_options[file] = opts
  end

  def yt_do_test(file, test)
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}", :helper=>ParserModule::DummyHelper.new(@@test_strings[file])).render(@@test_options[file])
    if should_be = yt_get('res', file, test)
      yt_assert should_be, res
    end
  end

  def test_single
    yt_do_test('zafu', 'only_hello')
  end

  def test_zazen_image_no_image
    file = 'zazen'
    test = 'image_no_image'
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}", :helper=>ParserModule::DummyHelper.new(@@test_strings[file])).render(:images=>false)
    assert_equal @@test_strings[file][test]['res'], res
  end

  def test_all_descendants
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>",
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    assert_equal ['add', 'add_link', 'each', 'pages', 'test', 'title'], block.all_descendants.keys.sort
    assert_equal 2, block.all_descendants['title'].size
    assert_equal ['add_link', 'title'], block.descendant('add').all_descendants.keys.sort
  end

  def test_descendants
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>",
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    assert_equal 2, block.descendants('title').size
    assert_equal ['test'], block.descendants('each')[0].descendants('test').map {|n| n.method}
    assert_equal [], block.descendants('each')[0].descendants('foo')
  end

  def test_ancestor
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>",
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    sub_block = block.descendant('add_link')
    assert_equal ['void', 'pages', 'add'], sub_block.ancestors.map{|a| a.method}
    assert_equal sub_block.ancestor('pages'), block.descendant('pages')
  end

  def test_public_descendants
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>",
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    block.all_descendants.merge('self'=>[block]).each do |k,blocks|
      blocks.each do |b|
        b.send(:remove_instance_variable, :@all_descendants)
        class << b
          def public_descendants
            if ['each'].include?(@method)
              {}
            else
              super
            end
          end
        end
      end
    end
    assert_equal ['add', 'add_link', 'each', 'pages', 'title'], block.all_descendants.keys.sort
    assert_equal ['test'], block.descendant('each').all_descendants.keys.sort
  end

  def test_root
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>",
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    sub_block = block.descendant('add_link')
    assert_equal 'add_link', sub_block.method
    assert_equal 'add', sub_block.parent.method
    assert_equal block, sub_block.root
  end

  yt_make
end