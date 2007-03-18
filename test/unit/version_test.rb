require File.dirname(__FILE__) + '/../test_helper'
class VersionTest < ZenaTestUnit
  
  def version(sym)
    secure(Node) { nodes(sym) }.version
  end
  
  def test_author
    login(:tiger)
    v = version(:status)
    assert_equal v[:user_id], v.author[:id]
  end
  
  def test_cannot_set_node_id
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_node_id = nodes_id(:lake) }
  end
  
  def test_cannot_set_site_id
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_site_id = sites_id(:ocean) }
  end
  
  def test_cannot_set_node_id_by_attribute
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_node_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_site_id_by_attribute
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_site_id=>sites_id(:ocean)) }
  end
  
  def test_cannot_set_node_id_on_create
    assert_raise(Zena::AccessViolation) { Node.create(:v_node_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_content_id
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.v_content_id = nodes_id(:lake) }
  end
  
  def test_cannot_set_content_id_by_attribute
    login(:tiger)
    node = secure(Node) { nodes(:status) }
    assert_raise(Zena::AccessViolation) { node.update_attributes(:v_content_id=>nodes_id(:lake)) }
  end
  
  def test_cannot_set_content_id_on_create
    assert_raise(Zena::AccessViolation) { Node.create(:v_content_id=>nodes_id(:lake)) }
  end
  
  def test_new_site_id_set
    login(:ant)
    node = secure(Node) { Node.create(:v_title=>'super', :parent_id=>nodes_id(:wiki)) }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:zena), node.version.site_id
  end
  
  def test_version_number_edit_by_attribute
    login(:ant)
    node = secure(Node) { nodes(:ant) }
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
    node = secure(Node) { nodes(:ant) }
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
    node = secure(Node) { Node.new(:parent_id=>1, :name=>'bob') }
    assert node.save
    vers = Version.new
    assert !vers.save
    assert_equal "can't be blank", vers.errors[:node]
    assert_equal "can't be blank", vers.errors[:user]
  end
  
  def test_update_content_one_version
    preserving_files("/data/test/pdf/36") do
      login(:ant)
      set_lang('en')
      node = secure(Node) { nodes(:forest_pdf) }
      assert_equal Zena::Status[:red], node.v_status
      assert_equal versions_id(:forest_red_en), node.c_version_id
      assert_equal 63569, node.c_size
      # single redaction: ok
      assert node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), 'Can edit node'
      # version and content did not change
      assert_equal versions_id(:forest_red_en), node.c_version_id
      assert_equal 29279, node.c_size
      assert_kind_of Tempfile, node.c_file
      assert_equal 29279, node.c_file.stat.size
    end
  end
  
  def test_cannot_change_content_if_many_uses
    preserving_files("/data/test/pdf") do
      login(:ant)
      set_lang('fr')
      node = secure(Node) { nodes(:forest_pdf) }
      old_vers_id = node.v_id
      # ant's english redaction
      assert_equal 'en', node.v_lang
      assert node.update_attributes(:v_title=>'les arbres')

      # new redaction for french
      assert_not_equal node.v_id, old_vers_id
      
      # new redaction points to old content
      assert_equal     node.v_content_id, old_vers_id
      
      login(:ant)
      set_lang('en')
      node = secure(Node) { nodes(:forest_pdf) }
      # get ant's english redaction
      assert_equal old_vers_id, node.v_id
      # try to edit content
      assert !node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Cannot be changed"
      assert_match "cannot change content (used by other versions)", node.errors[:base]
    end
  end
  
end
