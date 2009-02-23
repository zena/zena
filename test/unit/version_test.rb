require File.dirname(__FILE__) + '/../test_helper'
class VersionTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end
  
  def version(sym)
    secure!(Node) { nodes(sym) }.version
  end
  
  def test_author
    login(:tiger)
    v = versions(:opening_red_fr)
    assert_equal nodes_id(:tiger), v.author[:id]
  end
  
  def test_cannot_set_node_id
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_node_id = nodes_id(:lake) }
  end
  
  def test_cannot_set_site_id
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_site_id = sites_id(:ocean) }
  end
  
  def test_cannot_set_node_id_by_attribute
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_node_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_site_id_by_attribute
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_site_id=>sites_id(:ocean)) }
  end
  
  def test_cannot_set_node_id_on_create
    assert_raise(Zena::AccessViolation) { Node.create(:v_node_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_content_id
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_content_id = nodes_id(:lake) }
  end
  
  def test_cannot_set_content_id_by_attribute
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_content_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_content_id_on_create
    assert_raise(Zena::AccessViolation) { Node.create(:v_content_id=>nodes_id(:lake)) }
  end
  
  def test_new_site_id_set
    login(:ant)
    node = secure!(Node) { Node.create(:v_title=>'super', :parent_id=>nodes_id(:wiki)) }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:zena), node.version.site_id
  end
  
  def test_version_number_edit_by_attribute
    login(:ant)
    node = secure!(Node) { nodes(:ant) }
    version = node.version
    assert_equal 1, version.number
    # edit
    node.v_title='new title'
    version = node.version
    assert_nil version.number
    # save
    assert node.save, "Node can be saved"
    # version number changed
    version = node.version
    assert_equal 2, version.number
  end
    
  def test_version_number_edit
    login(:ant)
    node = secure!(Node) { nodes(:ant) }
    version = node.version
    assert_equal 1, version.number
    # can edit
    assert node.update_attributes(:v_title=>'new title')
    # saved
    # version number changed
    version = node.version
    assert_equal 2, version.number
  end
  
  def test_presence_of_node
    login(:tiger)
    node = secure!(Node) { Node.new(:parent_id=>nodes_id(:zena), :name=>'bob') }
    assert node.save
    vers = Version.new
    assert !vers.save
    assert_equal "node missing", vers.errors[:base]
  end
  
  def test_update_content_one_version
    preserving_files("test.host/data") do
      login(:ant)
      visitor.lang = 'en'
      node = secure!(Node) { nodes(:forest_pdf) }
      assert_equal Zena::Status[:red], node.v_status
      assert_equal versions_id(:forest_pdf_en), node.c_version_id
      assert_equal 63569, node.c_size
      # single redaction: ok
      assert node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), 'Can edit node'
      # version and content did not change
      assert_equal versions_id(:forest_pdf_en), node.c_version_id
      assert_equal 29279, node.c_size
      assert_kind_of File, node.c_file
      assert_equal 29279, node.c_file.stat.size
    end
  end
  
  def test_cannot_change_content_if_many_uses
    preserving_files("test.host/data") do
      login(:ant)
      visitor.lang = 'fr'
      node = secure!(Node) { nodes(:forest_pdf) }
      old_vers_id = node.v_id
      # ant's english redaction
      assert_equal 'en', node.v_lang
      assert node.update_attributes(:v_title=>'les arbres')
      
      assert node.propose # only proposed/published versions block

      # new redaction for french
      assert_not_equal node.v_id, old_vers_id
      
      # new redaction points to old content
      assert_equal     node.v_content_id, old_vers_id
      
      login(:ant)
      visitor.lang = 'en'
      node = secure!(Node) { nodes(:forest_pdf) }
      # get ant's english redaction
      assert_equal old_vers_id, node.v_id
      # try to edit content
      assert !node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Cannot be changed"
      assert node.errors[:c_file]
    end
  end
  
  def test_dynamic_attributes
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    version = node.send(:redaction)
    assert_nothing_raised { version.dyn['zucchini'] = 'courgettes' }
    assert_nothing_raised { version.d_zucchini = 'courgettes' }
    assert_equal 'courgettes', version.d_zucchini
    assert node.save
    
    node = secure!(Node) { nodes(:status) }
    version = node.version
    assert_equal 'courgettes', version.d_zucchini
  end
  
  def test_clone
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_whatever => 'no idea')
    assert_equal 'no idea', node.d_whatever
    version1_id = node.version[:id]
    assert node.publish
    
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_other => 'funny')
    version2_id = node.version[:id]
    assert_not_equal version1_id, version2_id
    assert_equal 'no idea', node.d_whatever
    assert_equal 'funny', node.d_other
  end
  
  def test_would_edit
    v = versions(:zena_en)
    assert v.would_edit?('title' => 'different')
    assert !v.would_edit?('title' => v.title)
    assert !v.would_edit?('status' => 999)
    assert !v.would_edit?('illegal_field' => 'whatever')
    assert !v.would_edit?('node_id' => 'whatever')
  end
  
  def test_would_edit_content
    v = versions(:ant_en)
    assert v.would_edit?('content_attributes' => {'name' => 'different'})
    assert !v.would_edit?('content_attributes' => {'name' => v.content.name})
  end
  
  def test_new_version_is_edited
    v = Version.new
    assert v.edited?
    v.title = 'hooo'
    assert v.edited?
  end
  
  def test_edited
    v = versions(:zena_en)
    assert !v.edited?
    v.status = 999
    assert !v.edited?
    v.title = 'new title'
    assert v.edited?
  end
  
  def test_edited_changed_content
    v = versions(:ant_en)
    v.content_attributes = {'name' => 'Invicta'}
    assert !v.edited?
    v.content_attributes = {'name' => 'New name'}
    assert v.edited?
  end
  
  def test_bad_lang
    login(:tiger)
    node = secure!(Page) { Page.create(:v_lang => 'io', :parent_id => nodes_id(:status), :name => 'hello', :v_title => '')}
    assert node.new_record?
    assert node.errors[:v_lang]
  end
end
