require File.dirname(__FILE__) + '/../test_helper'
require 'application'

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

class ApplicationControllerTest < Test::Unit::TestCase

  include ZenaTestController
  
  def setup
    @controller = ApplicationController.new
    init_controller
  end
  
  def test_acts_as_secure
    assert_nothing_raised { item = @controller.send(:secure,Item) { Item.find(ZENA_ENV[:root_id])}}
  end
  
  # render_and_cache and authorize tested in MainControllerTest
  
  def test_template
    wiki = @controller.send(:secure,Item) { Item.find(items_id(:wiki)) }
    assert_equal 'wiki', wiki.template
    @controller.instance_eval{ @item = wiki }
    assert_equal 'wiki', @controller.send(:template)
  end
  
  def test_class_template
    proj = @controller.send(:secure,Item) { Item.find(items_id(:cleanWater)) }
    assert_equal 'default', proj.template
    @controller.instance_eval{ @item = proj }
    assert_equal 'default_project', @controller.send(:template)
    proj.template = 'truc'
    assert_equal 'truc', proj.template
    assert_equal 'default', @controller.send(:template)
  end

  def test_custom_template
    assert_equal 'index', @controller.send(:template,'index')
  end
  
  def test_mode_template
    @controller.instance_eval { @params = {:mode=>'wiki'} }
    proj = @controller.send(:secure,Item) { Item.find(items_id(:cleanWater)) }
    @controller.instance_eval { @item = proj }
    assert_equal 'wiki', @controller.send(:template)
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
    @controller.instance_eval { @session = {:lang=>'en'} }
    assert_equal 'en', @controller.send(:prefix)
    @controller.instance_eval { @session = {:lang=>'ru'} }
    assert_equal 'ru', @controller.send(:prefix)
    @controller.instance_eval { @session = {:user=>{:id=>4, :lang=>'en', :groups=>[1,2,3]}} }
    assert_equal AUTHENTICATED_PREFIX, @controller.send(:prefix)
  end
  
  # authorize tested in 'MainController' tests
  
end
