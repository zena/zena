require File.dirname(__FILE__) + '/../test_helper'
require 'documents_controller'

# Re-raise errors caught by the controller.
class DocumentsController
  def rescue_action(e) raise e end;
end

class HelperDocumentsController < DocumentsController
  include DocumentsHelper
end

class DocumentsControllerTest < ZenaTestController
  
  def setup
    super
    @controller = DocumentsController.new
    init_controller
  end
  
  def test_create_template
    login(:tiger)
    post 'create', "node"=>{"klass"=>"Template", "name"=>"", "c_format"=>"", "c_mode"=>"tree", "c_klass"=>"Node", "v_summary"=>"", "parent_id"=>nodes_zip(:default)}
    assert_redirected_to :action => 'show'
    assert_kind_of Template, assigns(:node)
    assert_equal 'Node-tree', assigns(:node).name
  end
  
  #def test_new
  #  get 'new', :parent_id=>1
  #  assert_redirected_to :controller=>'main', :action=>'not_found'
  #  login(:tiger)
  #  get 'new', :parent_id=>1
  #  assert_response :success
  #  assert_template 'document/new'
  #  assert_tag :input, :attributes=>{:type=>'text', :id=>'document_name'}
  #  assert_tag :input, :attributes=>{:type=>'file', :id=>'document_c_file'}
  #end
  #
  #def test_create_pdf
  #  login(:tiger)
  #  preserving_files('/test.host/data/pdf') do
  #    post 'create', :document=>{:parent_id=>nodes_id(:zena), :c_file=>uploaded_pdf('water.pdf')}
  #    assert_response :redirect
  #    assert_redirected_to :action=>'show', :id=>assigns(:document)[:id]
  #    zena = secure(Node) { nodes(:zena) }
  #    docs = zena.documents
  #    assert_equal 'water', docs[0][:name]
  #  end
  #end
  #
  #def test_show
  #  get 'show'
  #  assert_redirected_to :controller=>'main', :action=>'not_found'
  #  get 'show', :id=>nodes_id(:bird_jpg)
  #  assert_response :success
  #  assert_template 'document/show'
  #end
  #
  #def test_data
  #  assert_routing '/data/pdf/15/water.pdf', :controller=>'document', :action=>'data', :version_id=>'15', :ext=>'pdf', :filename=>'water.pdf'
  #  get 'data', :version_id=>'15', :ext=>'pdf', :filename=>'water.pdf'
  #  assert_response :success
  #  assert_equal 'application/pdf', @response.headers['Content-Type']
  #end
  #
  #def test_remove_format_images # test cached data is removed
  #  # make 'flower' owned by :ant and used by managers
  #  Node.connection.execute "UPDATE nodes SET rgroup_id = 4, wgroup_id = 4, pgroup_id = 4, user_id=3 WHERE id = '#{nodes_id(:flower_jpg)}'"
  #  @perform_caching_bak = ApplicationController.perform_caching
  #  ApplicationController.perform_caching = true
  #  preserving_files('test.host/data/jpg') do
  #    without_files('test.host/public/data/jpg') do
  #      v_id = versions_id(:bird_jpg_en)
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}"), "No cached data for bird"
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/data/test/jpg/#{v_id}/bird-pv.jpg"), "No pv image for bird"
  #      get 'data', :version_id=>v_id, :ext=>'jpg', :filename=>'bird.jpg'
  #      assert_response :success
  #      assert File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}/bird.jpg"), "Bird full cached"
  #      get 'data', :version_id=>v_id, :ext=>'jpg', :filename=>'bird-pv.jpg'
  #      assert_response :success
  #      assert File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}/bird-pv.jpg"), "Bird pv cached"
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/data/test/jpg/#{v_id}/bird-pv.jpg"), "No pv image stored"
  #      
  #      # sweep_all
  #      img = nodes(:bird_jpg)
  #      img.send(:sweep_cache)
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}"), "No cached data for bird"
  #      
  #      login(:tiger)
  #      v_id = versions_id(:flower_jpg_en)
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}"), "No cached data for flower"
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/data/test/jpg/#{v_id}/flower-pv.jpg"), "No pv image for flower"
  #      get 'data', :version_id=>v_id, :ext=>'pdf', :filename=>'flower.jpg'
  #      assert_response :success
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}/flower.jpg"), "No flower full cached"
  #      get 'data', :version_id=>v_id, :ext=>'pdf', :filename=>'flower-pv.jpg'
  #      assert_response :success
  #      assert ! File.exist?("#{SITES_ROOT}/test.host/public/data/jpg/#{v_id}/flower-pv.jpg"), "No flower pv cached"
  #      assert File.exist?("#{SITES_ROOT}/test.host/data/test/jpg/#{v_id}/flower-pv.jpg"), "PV image stored"
  #    end
  #  end
  #  ApplicationController.perform_caching = @perform_caching
  #end
  #
  #def test_cannot_fill_cache_with_random_format
  #  @perform_caching_bak = ApplicationController.perform_caching
  #  ApplicationController.perform_caching = true
  #  preserving_files('data/test/jpg') do
  #    without_files('public/data/jpg') do
  #      get 'data', :version_id=>20, :ext=>'jpg', :filename=>'bird-whatever.jpg'
  #      assert_redirected_to  :action=>'not_found', :controller=>'main'
  #    end
  #  end
  #  ApplicationController.perform_caching = @perform_caching
  #end
  #def test_data_bad_name
  #  get 'data', :version_id=>'15', :ext=>'pdf', :filename=>'blue.jpg'
  #  assert_response :redirect
  #end
  #
  #def test_data_resized_image
  #  get 'data', :version_id=>'20', :ext=>'jpg', :filename=>'bird.jpg'
  #  assert_response :success
  #  assert_equal 'image/jpeg', @response.headers['Content-Type']
  #  get 'data', :version_id=>'20', :ext=>'jpg', :filename=>'bird-pv.jpg'
  #  assert_response :success
  #  assert_equal 'image/jpeg', @response.headers['Content-Type']
  #end
  #
  #def test_list
  #  get 'list', :parent_id=>1
  #  assert_response :success
  #  assert_template 'document/_list'
  #end
  #
  #def test_create_jpg
  #  login(:tiger)
  #  post 'create', :document=>{:parent_id=>nodes_id(:zena), :c_file=>uploaded_jpg('bird.jpg')}
  #  assert_response :success
  #  assert_template 'document/create'
  #  zena = secure(Node) { nodes(:zena) }
  #  docs = zena.documents
  #  assert_equal 'bird', docs[0][:name]
  #end
  #
  #def test_img
  #  assert false
  #end
  #
  #def test_template
  #  assert false
  #end
  #
  #def test_form_tabs
  #  @controller = HelperDocumentController.new
  #  init_controller
  #  assert_equal [["file", "file"], ["text_doc", "text_doc"]], @controller.send(:form_tabs)
  #end
end
