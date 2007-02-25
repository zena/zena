require File.dirname(__FILE__) + '/../test_helper'
require 'application'

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

class ApplicationControllerTest < Test::Unit::TestCase
  include ZenaTestController
  
  def setup
    super
    @controller = ApplicationController.new
    init_controller
  end
  
  def test_acts_as_secure
    assert_nothing_raised { node = @controller.send(:secure,Node) { Node.find(ZENA_ENV[:root_id])}}
  end
  
  # render_and_cache and authorize tested in MainControllerTest
  
  def test_skin
    wiki = @controller.send(:secure,Node) { Node.find(nodes_id(:wiki)) }
    assert_equal 'wiki', wiki.skin
    @controller.instance_eval{ @node = wiki }
    assert_equal 'wiki', @controller.send(:skin)
  end
  
  def test_class_skin
    proj = @controller.send(:secure,Node) { Node.find(nodes_id(:cleanWater)) }
    assert_equal 'default', proj.skin
    @controller.instance_eval{ @node = proj }
    assert_equal 'default_project', @controller.send(:skin)
    proj.skin = 'truc'
    assert_equal 'truc', proj.skin
    assert_equal 'default', @controller.send(:skin)
  end
  
  def test_general_class_skin
    letter = @controller.send(:secure, Node) { Node.find(nodes_id(:letter)) }
    assert_equal 'default', letter.skin
    @controller.instance_eval{ @node = letter }
    assert_equal 'any_letter', @controller.send(:skin)
  end
  
  def test_custom_skin
    assert_equal 'index', @controller.send(:skin,'index')
  end
  
  def test_mode_skin
    @controller.instance_eval { @params = {:mode=>'wiki'} }
    proj = @controller.send(:secure,Node) { Node.find(nodes_id(:cleanWater)) }
    @controller.instance_eval { @node = proj }
    assert_equal 'wiki', @controller.send(:skin)
  end
  
  def test_form_tabs
    page = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    doc  = @controller.send(:secure, Node) { Node.find(nodes_id(:water_pdf)) }
    @controller.instance_eval{ @node = page }
    assert_equal 'forms/default', @controller.send(:form_skin)
    @controller.instance_eval{ @node = doc  }
    assert_equal 'forms/any_document', @controller.send(:form_skin)
  end
  
  # // test methods common to controllers and views // #
  
  def test_lang
    assert_equal ZENA_ENV[:default_lang], @controller.send(:lang)
    @controller.instance_eval { @session = {:lang=>'io'} }
    assert_equal 'io', @controller.send(:lang)
  end
  
  # trans tested in ApplicationHelperTest
  def test_trans
    assert_equal 'yoba', @controller.send(:trans,'yoba')
    @controller.instance_eval { @session = {:lang=>'fr'} }
    assert_equal 'lundi', @controller.send(:trans,'Monday')
    @controller.instance_eval { @session = {:lang=>'en', :translate=>true} }
    assert_equal 'yoba', @controller.send(:trans,'yoba')
  end
  
  def test_prefix
    bak = ZENA_ENV[:monolingual]
    ZENA_ENV[:monolingual] = false
    @controller.instance_eval { @session = {:lang=>'en'} }
    assert_equal 'en', @controller.send(:prefix)
    @controller.instance_eval { @session = {:lang=>'ru'} }
    assert_equal 'ru', @controller.send(:prefix)
    @controller.instance_eval { @session = {:user=>{:id=>4, :lang=>'en', :groups=>[1,2,3]}} }
    assert_equal AUTHENTICATED_PREFIX, @controller.send(:prefix)
    ZENA_ENV[:monolingual] = true
    @controller.instance_eval { @session = {:user=>nil} }
    assert_equal '', @controller.send(:prefix)
    @controller.instance_eval { @session = {:user=>{:id=>4, :lang=>'en', :groups=>[1,2,3]}} }
    assert_equal AUTHENTICATED_PREFIX, @controller.send(:prefix)
    ZENA_ENV[:monolingual] = bak
  end
  
  def test_node_url
    node = @controller.send(:secure, Node) { Node.find(nodes_id(:status)) }
    assert_equal ['cleanWater','node12'], @controller.send(:node_url,node)[:path]
    node = @controller.send(:secure, Node) { Node.find(nodes_id(:wiki)) }
    assert_equal ['node19'], @controller.send(:node_url,node)[:path]
  end
  # authorize tested in 'MainController' tests
  
end
