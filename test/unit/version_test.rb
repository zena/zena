require 'test_helper'
class VersionTest < Zena::Unit::TestCase

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
    node = Node.new(:v_node_id => 1234)
    assert_nil node.version.node_id
  end

  def test_cannot_set_node_id_with_attributes
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    original_node_id = node.version.node_id
    node.update_attributes(:v_node_id => nodes_id(:lake) )
  end

  def test_cannot_set_site_id_with_new_record
    login(:tiger)
    node = Node.new(:site_id => 1234)
    assert_nil node.site_id
  end

  def test_cannot_set_site_id_with_old_record
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    original_site_id = node.site_id
    node.update_attributes(:v_site_id => 1234)
    assert_equal original_site_id, node.site_id
  end

  def test_cannot_set_site_id_by_attribute
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    original_site_id = node.site_id
    node.update_attributes(:v_site_id=>sites_id(:ocean))
    assert_equal original_site_id, node.site_id
  end

  def test_cannot_set_node_id_on_create
    login(:tiger)
    node = Node.create(:v_node_id=>nodes_id(:lake))
    assert_nil node.version.node_id
  end

  def test_cannot_set_content_id
    login(:tiger)
    node = Node.new(:v_content_id => nodes_id(:lake))
    assert_nil node.version.content_id
  end

  def test_cannot_set_content_id_by_attribute
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes(:v_content_id=>nodes_id(:lake))
    assert_nil node.version.content_id
  end

  def test_cannot_set_content_id_on_create
    login(:tiger)
    node = Node.create(:v_content_id=>nodes_id(:lake))
    assert_nil node.version.content_id
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
    node.attributes = {:v_title => 'new title'}
    version = node.version
    assert version.new_record?
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
    assert_equal "can't be blank", vers.errors[:node]
  end

  def test_update_content_one_version
    preserving_files("test.host/data") do
      login(:ant)
      visitor.lang = 'en'
      node = secure!(Node) { nodes(:forest_pdf) }
      assert_equal Zena::Status[:red], node.version.status
      assert_equal versions_id(:forest_pdf_en), node.version.content.version_id
      assert_equal 63569, node.version.content.size
      # single redaction: ok
      assert node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), 'Can edit node'
      # version and content did not change
      assert_equal versions_id(:forest_pdf_en), node.version.content.version_id
      assert_equal 29279, node.version.content.size
      assert_kind_of File, node.version.content.file
      assert_equal 29279, node.version.content.file.stat.size
    end
  end

  def test_remap_master_version_if_many_use_same_content
    preserving_files("test.host/data") do
      login(:ant)
      visitor.lang = 'fr'
      node = secure!(Node) { nodes(:forest_pdf) }
      old_vers_id = node.version.id
      # ant's english redaction
      assert_equal 'en', node.version.lang
      content_id_before_move = node.version.content.id

      # 1. Create a new version in french
      assert node.update_attributes(:v_title=>'les arbres')

      assert node.propose # only proposed/published versions block
      assert_equal 'fr', node.version.lang

      # new redaction for french
      assert_not_equal node.version.id, old_vers_id

      # 2. New redaction points to old content
      assert_equal     node.version.content_id, old_vers_id

      login(:ant)
      visitor.lang = 'en'
      node = secure!(Node) { nodes(:forest_pdf) }

      # 3. Edit ant's original (english) redaction
      assert_equal old_vers_id, node.version.id

      # edit content (should move content's master_version to other version and create a new content)
      assert node.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Cannot be changed"
      assert_nil node.version.content_id # we have our own content
      assert_equal node.version.id, node.version.content.version_id
      # this is still the original (english) version
      assert_equal old_vers_id, node.version.id

      login(:ant)
      visitor.lang = 'fr'
      node = secure!(Node) { nodes(:forest_pdf) }

      # 4. The content has become our own
      assert_equal content_id_before_move, node.version.content.id
      assert_nil node.version.content_id
      assert_equal node.version.id, node.version.content.version_id
    end
  end

  def test_dynamic_attributes
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    version = node.send(:redaction)
    assert_nothing_raised { version.dyn['zucchini'] = 'courgettes' }
    assert_nothing_raised { version.dyn_attributes = {'zucchini' => 'courgettes' }}
    assert_equal 'courgettes', version.dyn['zucchini']
    assert node.save

    node = secure!(Node) { nodes(:status) }
    version = node.version
    assert_equal 'courgettes', version.dyn['zucchini']
  end

  def test_clone
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_whatever => 'no idea')
    assert_equal 'no idea', node.version.dyn['whatever']
    version1_id = node.version[:id]
    assert node.publish
    version1_publish_from = node.version.publish_from

    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_other => 'funny')
    version2_id = node.version[:id]
    assert_not_equal version1_id, version2_id
    assert_equal 'no idea', node.version.dyn['whatever']
    assert_equal 'funny', node.version.dyn['other']
    assert_equal version1_publish_from, node.version.publish_from
  end

  def test_would_edit
    v = versions(:zena_en)
    assert v.would_edit?('title' => 'different')
    assert v.would_edit?('dyn_attributes' => {'foo' => 'different'})
    assert !v.would_edit?('title' => v.title)
    assert !v.would_edit?('status' => Zena::Status[:red])
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
    assert node.errors[:version_lang].any?
  end

  def test_set_v_lang
    login(:tiger)
    assert_equal 'en', visitor.lang
    node = secure!(Page) { Page.create(:v_lang => 'fr', :parent_id => nodes_id(:status), :name => 'hello', :v_title => '')}
    assert !node.new_record?
    assert_equal 'fr', node.version.lang
  end

  def test_should_parse_publish_from_date
    I18n.locale = 'fr'
    visitor.time_zone = 'Asia/Jakarta'
    v = Version.new('publish_from' => '9-9-2009 15:17')
    assert_equal Time.utc(2009,9,9,8,17), v.publish_from
  end
end
