require File.dirname(__FILE__) + '/../test_helper'
require 'main_controller'

# Re-raise errors caught by the controller.
class MainController; def rescue_action(e) raise e end; end

class DocumenControllerTest < Test::Unit::TestCase
  include ZenaTestController
  
  def setup
    @controller = DocumentController.new
    init_controller
  end
  
  def test_new
    get 'new', :parent_id=>1
    assert_redirected_to :controller=>'main', :action=>'not_found'
    login(:tiger)
    get 'new', :parent_id=>1
    assert_response :success
    assert_template 'document/new'
    assert_tag :input, :attributes=>{:type=>'text', :id=>'document_name'}
    assert_tag :input, :attributes=>{:type=>'file', :id=>'document_file'}
  end
  
  def test_create_pdf
    login(:tiger)
    post 'create', :document=>{:parent_id=>items_id(:zena), :file=>uploaded_pdf('water.pdf')}
    assert_response :success
    assert_template 'document/create'
    zena = secure(Item) { items(:zena) }
    docs = zena.documents
    assert_equal 'water.pdf', docs[0][:name]
  end
  
  def test_list
    assert false, 'todo'
  end
  
  def test_create_jpg
    login(:tiger)
    post 'create', :document=>{:parent_id=>items_id(:zena), :file=>uploaded_jpg('bird.jpg')}
    assert_response :success
    assert_template 'document/create'
    zena = secure(Item) { items(:zena) }
    docs = zena.documents
    assert_equal 'bird.jpg', docs[0][:name]
  end
  
end
