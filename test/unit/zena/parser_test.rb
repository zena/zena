require 'test_helper'

unless Module.const_defined?(:ActiveRecord)
  # blank definition from active_support/core_ext/blank.rb
  class String #:nodoc:
    def blank?
      empty? || strip.empty?
    end
  end
end

module ZafuTestTags
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

class String
  def pseudo_id(*args)
    self
  end
end


class ParserTest < Test::Unit::TestCase
  module Mock
    def find_node_by_pseudo(*args)
      args[0]
    end
  end

  class ParserTestHelper < Zena::Parser::DummyHelper
    include ParserTest::Mock
  end
  yamltest :files => [:zazen] #, :options => {:latex => {:module => :zazen, :output => 'latex'}}
  MODULES = {
    :zazen         => [Zena::Parser::ZazenRules, Zena::Parser::ZazenTags],
  }
  @@test_parsers = {}
  @@test_options = {}

  @@file_list.each do |file, file_path, opts|
    @@test_parsers[file] = Zena::Parser.parser_with_rules(MODULES[file.to_sym], Mock)
    @@test_options[file] = opts
  end

  def yt_do_test(file, test)
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}",
      :helper => ParserTestHelper.new(@@test_strings[file])
    ).render(@@test_options[file])
    if should_be = yt_get('res', file, test)
      yt_assert should_be, res
    end
  end

  def test_zazen_image_no_image
    file = 'zazen'
    test = 'image_no_image'
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}",
      :helper => ParserTestHelper.new(@@test_strings[file])
    ).render(:images=>false)
    assert_equal @@test_strings[file][test]['res'], res
  end

  yt_make
end