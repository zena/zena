require File.dirname(__FILE__) + '/../test_helper'
require 'document_controller'

# Re-raise errors caught by the controller.
class DocumentController
  def rescue_action(e) raise e end;
end

class HelperDocumentController < DocumentController
  include DocumentHelper
end

class DocumenControllerTest < Test::Unit::TestCase
  include ZenaTestController
  
  def setup
    super
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
    assert_tag :input, :attributes=>{:type=>'file', :id=>'document_c_file'}
  end
  
  def test_create_pdf
    login(:tiger)
    preserving_files('/data/test/pdf') do
      post 'create', :document=>{:parent_id=>nodes_id(:zena), :c_file=>uploaded_pdf('water.pdf')}
      assert_response :redirect
      assert_redirected_to :action=>'show', :id=>assigns(:document)[:id]
      zena = secure(Node) { nodes(:zena) }
      docs = zena.documents
      assert_equal 'water', docs[0][:name]
    end
  end
  
  def test_show
    get 'show'
    assert_redirected_to :controller=>'main', :action=>'not_found'
    get 'show', :id=>nodes_id(:bird_jpg)
    assert_response :success
    assert_template 'document/show'
  end
  
  def test_data
    assert_routing '/data/pdf/15/water.pdf', :controller=>'document', :action=>'data', :version_id=>'15', :ext=>'pdf', :filename=>'water.pdf'
    get 'data', :version_id=>'15', :ext=>'pdf', :filename=>'water.pdf'
    assert_response :success
    assert_equal 'application/pdf', @response.headers['Content-Type']
  end
  
  def test_data_bad_name
    get 'data', :version_id=>'15', :ext=>'pdf', :filename=>'blue.jpg'
    assert_response :redirect
  end
  
  def test_data_resized_image
    get 'data', :version_id=>'20', :ext=>'jpg', :filename=>'bird.jpg'
    assert_response :success
    assert_equal 'image/jpeg', @response.headers['Content-Type']
    get 'data', :version_id=>'20', :ext=>'jpg', :filename=>'bird-pv.jpg'
    assert_response :success
    assert_equal 'image/jpeg', @response.headers['Content-Type']
  end
  
  def test_list
    get 'list', :parent_id=>1
    assert_response :success
    assert_template 'document/_list'
  end
  
  def test_create_jpg
    login(:tiger)
    post 'create', :document=>{:parent_id=>nodes_id(:zena), :c_file=>uploaded_jpg('bird.jpg')}
    assert_response :success
    assert_template 'document/create'
    zena = secure(Node) { nodes(:zena) }
    docs = zena.documents
    assert_equal 'bird', docs[0][:name]
  end
  
  def test_img
    assert false
  end
  
  def test_template
    assert false
  end
  
  def test_form_tabs
    @controller = HelperDocumentController.new
    init_controller
    assert_equal [["file", "file"], ["text_doc", "text_doc"]], @controller.send(:form_tabs)
  end
end
