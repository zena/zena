require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'yaml'
module TestHelper
end
class TestController < ApplicationController
  helper_method :template_text_for_url, :template_url_for_asset
  before_filter :set_context
  before_filter :authorize
  before_filter :set_env
  ZazenParser = Parser.parser_with_rules(Zazen::Rules, Zazen::Tags)
  ZafuParser  = Parser.parser_with_rules(Zafu::Rules, Zena::Rules, Zafu::Tags, Zena::Tags)
  
  class << self
    def templates=(templates)
      @@templates = templates
    end
  end
  def test_compile
    #response.template
    render :text=>ZafuParser.new_with_url(@test_url, :helper=>response.template).render
  end

  def test_render
    render :inline=>@text
  end

  def test_zazen
    render :text=>ZazenParser.new(@text, :helper=>response.template).render
  end

  private
  # by pass application before actions
  def authorize
  end
  def set_env
  end

  def set_context
    session[:user] = User.find(@params[:user_id])[:id] # make sure the user exists
    session[:lang] = @params[:prefix]
    @node = secure(Node) { Node.find(@params[:node_id])}
    @text = @params[:text]
    @test_url  = @params[:url]
    @params.delete(:user_id)
    @params.delete(:node_id)
    @params.delete(:text)
    @params.delete(:url)
    sess = @session
    response.template.instance_eval { @session = {} } # if accessing session when rendering, should be like no one there yet.
  end

  def template_text_for_url(url)
    url = url[1..-1] # strip leading '/'
    @current_template = url
    url = url.gsub('/','_')
    if test = @@templates[url]
      test['src']
    else
      nil
    end
  end

  def template_url_for_asset(type,url)
    # current_template = @current_template || "/"
    # we assume current_template is /projects/cleanWater for testing
    current_template = 'projects/cleanWater'
    path = current_template.split('/') + url.split('/')
    doc = secure(Document) { Document.find_by_path(path)}
    url = url_for(data_url(doc))
    if url =~ %r{http://test.host(.*)}
      $1
    else
      url
    end
  end
end

class HelperTest < Test::Unit::TestCase
  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end
  class << self
    def testfile(*files)
      @@test_strings = {}
      @@test_methods = {}
      @@test_parsers = {}
      @@test_files = []
      files.each do |file|
        file = file.to_s
        strings = {}
        test_methods = []
        YAML::load_documents( File.open( "#{file}.yml" ) ) do |doc|
          doc.each do |elem|
            test_methods << elem[0]
            strings[elem[0]] = elem[1]
          end
        end
        class_eval <<-END
          def #{file}
            @@test_strings['#{file}']
          end
        END
        @@test_strings[file] = strings.freeze
        mod_name = file.split("_").first.capitalize
        @@test_methods[file] = test_methods
        @@test_files << file
      end
    end
    def make_tests
      return unless @@test_methods
      tests = self.instance_methods.reject! {|m| !( m =~ /^test_/ )}
      @@test_files.each do |tf|
        @@test_methods[tf].each do |test|
          unless tests.include?("test_#{tf}_#{test}")
            puts "ERROR: already defined test #{tf}.yml #{test}}" if tests.include?("test_#{tf}_#{test}")
            tests << "test_#{tf}_#{test}"
            class_eval <<-END
              def test_#{tf}_#{test}
                do_test(#{tf.inspect},#{test.inspect})
              end
            END
          end
        end
      end
    end
  end
  
  def do_test(file, test)
    src = @@test_strings[file][test]['src']
    tem = @@test_strings[file][test]['tem']
    res = @@test_strings[file][test]['res']
    context = @@test_strings[file][test]['context'] || {}
    default_context = @@test_strings[file]['default']['context'] || {'node'=>'status', 'visitor'=>'ant', 'lang'=>'en'}
    context = default_context.merge(context)
    # set context
    params = {}
    params[:user_id] = users_id(context['visitor'].to_sym)
    params[:node_id] = nodes_id(context['node'].to_sym)
    params[:prefix] = context['lang']
    params[:url] = "/#{test.to_s.gsub('_', '/')}"
    TestController.templates = @@test_strings[file]
    if src
      post 'test_compile', params
      template = @response.body
      if tem
        if tem[0..0] == '/'
          assert_match %r{#{tem[1..-2]}}m, template
        else
          assert_equal tem, template
        end
      end
    else
      template = tem
    end
    if res
      params[:text] = template
      post 'test_render', params
      result = @response.body
      if res[0..0] == '/'
        assert_match %r{#{res[1..-2]}}m, result
      else
        assert_equal res, result
      end
    end
  end
end
