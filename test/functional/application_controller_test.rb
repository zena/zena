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
  
  def test_general_class_template
    letter = @controller.send(:secure, Item) { Item.find(items_id(:letter)) }
    assert_equal 'default', letter.template
    @controller.instance_eval{ @item = letter }
    assert_equal 'any_letter', @controller.send(:template)
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
  
  def test_form_template
    page = @controller.send(:secure, Item) { Item.find(items_id(:status))    }
    doc  = @controller.send(:secure, Item) { Item.find(items_id(:water_pdf)) }
    @controller.instance_eval{ @item = page }
    assert_equal 'forms/default', @controller.send(:form_template)
    @controller.instance_eval{ @item = doc  }
    assert_equal 'forms/any_document', @controller.send(:form_template)
  end
  
  def test_parse_date
    assert_equal Time.gm(2006,11,10), @controller.send(:parse_date,'2006-11-10', '%Y-%m-%d')
    assert_equal Time.gm(2006,11,10), @controller.send(:parse_date,'10.11 2006', '%d.%m %Y')
    assert_equal Time.gm(2006,11,10), @controller.send(:parse_date,'10.11 / 06', '%d.%m.%y')
    assert_equal Time.gm(Time.now.year,11,10), @controller.send(:parse_date,'11-10', '%m.%d')
  end
  
  def test_parse_date_time
    assert_equal Time.gm(2006,11,10,12,30), @controller.send(:parse_date,'2006-11-10 12:30', '%Y-%m-%d %H:%M')
    assert_equal Time.gm(2006,11,10,12,30), @controller.send(:parse_date,'2006-11-10 12:30')
    assert_equal Time.gm(2006,11,10,12,30), @controller.send(:parse_date,'10.11.2006 12:30', '%d.%m.%Y %H:%M')
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
