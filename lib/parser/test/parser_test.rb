require File.join(File.dirname(__FILE__) , 'testhelp.rb')
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

module Zafu
  module Tags
    def r_hello
      'hello world!'
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
      expand_with(@params)
    end
    
    def r_missing
      return unless check_params(:good, :night)
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

class ParserTest < Test::Unit::TestCase
  testfile :zafu, :zafu_asset, :zafu_insight, :zazen
  def test_single
    do_test('zafu', 'multiple_param')
  end
  
  def test_zazen_image_no_image
    file = 'zazen'
    test = 'image_no_image'
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}", :helper=>ParserModule::DummyHelper.new(@@test_strings[file])).render(:images=>false)
    assert_equal @@test_strings[file][test]['res'], res
  end
  
  def test_descendants
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>", 
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    assert_equal ['add', 'add_link', 'each', 'pages', 'test', 'title'], block.descendants.keys.sort
    assert_equal 2, block.descendants['title'].size
    assert_equal ['add_link', 'title'], block.descendant('add').descendants.keys.sort
  end
  
  
  def test_public_descendants
    block = @@test_parsers['zafu'].new(
    "<r:pages><r:each><b do='test'/></r:each><r:add><p><i do='add_link'/><b do='title'/></p></r:add><b do='title'/></r:pages>", 
    :helper=>ParserModule::DummyHelper.new(@@test_strings['basic']))
    block.descendants.merge('self'=>[block]).each do |k,blocks|
      blocks.each do |b|
        b.send(:remove_instance_variable, :@descendants)
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
    assert_equal ['add', 'add_link', 'each', 'pages', 'title'], block.descendants.keys.sort
    assert_equal ['test'], block.descendant('each').descendants.keys.sort
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
  
  make_tests
end