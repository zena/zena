require File.dirname(__FILE__) + '/../test_helper'
require 'trans_controller'

# Re-raise errors caught by the controller.
class TransController; def rescue_action(e) raise e end; end

class TransControllerTest < Test::Unit::TestCase

  include ZenaTestController

  def setup
    @controller = TransController.new
    init_controller
  end

  # Replace this with your real tests.
  def test_before_filter
    get 'edit', :id=>17
    assert_redirected_to :action => 'not_found', :controller=>'main'
    login(:lion)
    get 'edit', :id=>17
    assert_template 'trans/edit'
  end

  def test_edit
    login(:lion)
    get 'edit', :id=>13
    assert_template 'trans/edit'
    assert_tag :tag=>'form', :attributes=>{:action=>'/z/trans/update/13'}
    assert_tag :tag=>'input', :attributes=>{:id=>'trans_value', :value=>'Monday'}
  end

  def test_edit_other_lang
    login(:lion)
    session[:lang] = 'es'
    get 'edit', :id=>13
    assert_template 'trans/edit'
    assert_tag :tag=>'form', :attributes=>{:action=>'/z/trans/update/13'}
    assert_tag :tag=>'input', :attributes=>{:id=>'trans_value', :value=>'Monday'}
    session[:lang] = 'fr'
    get 'edit', :id=>13
    assert_template 'trans/edit'
    assert_tag :tag=>'form', :attributes=>{:action=>'/z/trans/update/13'}
    assert_tag :tag=>'input', :attributes=>{:id=>'trans_value', :value=>'lundi'}
  end
  
  def test_update_lunes
    login(:lion)
    session[:lang] = 'es'
    post 'update', :id=>'13', :trans=>{:value=>'Lunes'}
    assert_equal 'Lunes', response.body
    assert_equal 'Lunes', TransPhrase.translate('Monday').into('es')
  end
  
  def test_lang_menu
    get 'lang_menu'
    assert_response :success
    assert_template 'trans/lang_menu'
    assert_match %r{form.*onChange="window.location.href='\?lang='\+\(this.options\[this.selectedIndex\].value\)"}m, response.body
  end
  
end
