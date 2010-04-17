require 'test_helper'

class TemplateTest < Zena::Unit::TestCase
  
  context 'Creating a template' do
    setup do
      login(:tiger)
    end
    
    should 'create a new node' do
      assert_difference('Node.count', 1) do
        secure(Template) { Template.create(:parent_id => nodes_id(:default), :name => 'Project.zafu') }
      end
    end
    
    should 'create a new template index entry' do
      assert_difference('TemplateIndex.count', 1) do
        secure(Template) { Template.create(:parent_id => nodes_id(:default), :name => 'Project.zafu') }
      end
    end
  end
  
  def test_create_simplest
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'super.zafu')}
    assert_kind_of Template, doc
    assert doc.new_record?
    assert ['Invalid parent (section is not a skin)'], doc.errors[:parent_id]
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.zafu')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.content_type
    assert_equal 'zafu', doc.ext
  end

  def test_create_empty_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.zafu', :mode => '')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.content_type
    assert_nil doc.mode
    assert_equal 'zafu', doc.ext
  end

  def test_create_empty_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id => nodes_id(:default), :target_klass=>'Section') }
    err doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.content_type
    assert_nil doc.mode
    assert_equal 'zafu', doc.ext
    assert_equal 'Section', doc.target_klass
    assert_equal 'Section', doc.name
    assert_equal 'html', doc.format
    assert_equal 'NPS', doc.tkpath
  end

  def test_create_with_format
    login(:tiger)
    doc = secure!(Template) { Template.create("name"=>"Node-tree", "format"=>"xml", "summary"=>"", "parent_id"=>nodes_id(:default))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'Node-tree-xml', doc.name
    assert_equal 'tree', doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Node', doc.target_klass
    assert_equal 'N', doc.tkpath
    assert_equal 'zafu', doc.ext
  end

  def test_create_with_file
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'skiny',
      :file=>uploaded_fixture('some.txt', content_type="text/zafu", 'smoke'))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'skiny.zafu', doc.filename

    sub = secure!(Document) { Document.create(:parent_id=>doc[:id], :name=>'sub.html')}
    assert_kind_of Template, sub
    assert !sub.new_record?, "Not a new record"
  end

  def test_set_by_name
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project-collab-xml', doc.name
  end

  def test_set_by_name_without_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'Project--xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.name
  end

  def test_set_name_with_title
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project-collab-xml', doc.name
  end

  def test_set_blank_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => 'collab', 'target_klass' => 'Page', 'name' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-collab', doc.name
  end

  def test_change_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:name => "Page-super")
    assert_equal 'super', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-super', doc.name
  end

  def test_update_title_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:mode => "", :title=> "Project-collab-xml")
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project--xml', doc.name
    assert_equal 'Project--xml', doc.version.title
  end

  def test_update_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:mode => "", :name => "Project-collab-xml") # name does not change, only mode is updated
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.name
    assert_equal 'Project--xml', doc.version.title
  end

  def test_change_name_not_master
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:name => "simple-thing")
    assert_nil doc.target_klass
    assert_nil doc.mode
    assert_nil doc.format
    assert_nil doc.tkpath
    assert_equal 'simple-thing', doc.name
  end

  def test_set_name_no_extension
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project-collab', doc.name
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
  end

  def test_set_name_not_master_template
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'foobar.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_nil doc.format
    assert_nil doc.tkpath
    assert_nil doc.target_klass
    assert_equal 'foobar', doc.name
  end

  def test_set_target_klass
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Spider-man-xml',
                                             :target_klass => 'Page',
                                             :format => 'ical')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Page-man-ical', doc.name
    assert_equal 'man', doc.mode
    assert_equal 'ical', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
  end

  def test_set_blank_name_not_unique
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'name' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact', doc.name
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'name' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcard', doc.name
  end

  def test_update_format_updates_name
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'name' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcard', doc.name
    assert doc.update_attributes(:format => 'vcf')
    assert_equal 'vcf', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcf', doc.name
  end

  def test_update_text
    login(:lion)
    doc = secure!(Template) { nodes(:Project_zafu) }
    assert doc.update_attributes('text'=>'DUMMY')
    content = template_contents(:Project_zafu)
    assert_equal 'default', content.skin_name
    assert_equal 'Project', content.target_klass
    assert_equal 'html', content.format
    assert_nil content.mode
    assert_equal 'NPP', content.tkpath
  end

  def test_default_text
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'target_klass' => 'Contact', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{include.*Node}, doc.version.text
  end

  def test_default_text_Node
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'target_klass' => 'Node', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{xmlns.*www\.w3\.org.*body}m, doc.version.text
  end

  def test_default_text_other_format
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'format' => 'vcard', 'target_klass' => 'Node', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.version.text.blank?
  end

  def test_move_bad_parent
    login(:lion)
    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }
    assert !doc.update_attributes(:parent_id => nodes_id(:collections))
    assert_equal 'Invalid parent (section is not a Skin)', doc.errors[:parent_id]
  end

  def test_move
    login(:lion)
    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }

    assert_equal 'wikiSkin', doc.skin_name
    assert doc.update_attributes(:parent_id => nodes_id(:default))

    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }
    assert_equal 'default', doc.skin_name
  end

  def test_update_same_text
    login(:tiger)
    tmpt = secure(Template) { Template.create(:parent_id=>nodes_id(:default), 'format' => 'vcard', 'target_klass' => 'Node', 'name' => '', 'v_status' => Zena::Status[:pub], 'file' =>
      uploaded_fixture('some.txt', 'text/zafu')) }
    assert_kind_of Template, tmpt
    Zena::Db.set_attribute(tmpt, :updated_at, Time.gm(2006,04,11))
    assert_equal Zena::Status[:pub], tmpt.version.status

    tmpt = secure(Node) { Node.find(tmpt[:id]) } # reload

    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(uploaded_text('some.txt').read)
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(tmpt.file.read)
    tmpt.file.rewind
    assert_equal 1, tmpt.versions.count
    assert_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')
    assert tmpt.update_attributes(:file => uploaded_text('some.txt'))
    assert_equal 1, tmpt.versions.count
    assert_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')

    tmpt = secure(Node) { Node.find(tmpt[:id]) } # reload
    tmpt.version.backup = true
    assert tmpt.update_attributes(:file => uploaded_text('other.txt'))
    assert_equal 2, tmpt.versions.count
    assert_not_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')
  end

  context 'A visitor with drive access' do
    setup do
      login(:lion)
    end

    context 'on a template with a removed version' do
      setup do
        @node = secure(Node) { nodes(:Project_zafu) }
        @node.update_attributes('text' => 'fuzy')
        @node.remove
      end

      should 'be able to destroy version' do
        assert_difference('Version.count', -1) do
          assert_difference('Node.count', 0) do
            assert @node.version.destroy
          end
        end
      end
    end

    should 'be able to create a template with no format, mode or target_klass' do
      assert_difference('Node.count', 1) do
        @node = secure(Document) { Document.create(:parent_id => nodes_id(:default), :name=>'foo.zafu') }
      end
      content = @node
      assert_nil content.format
      assert_nil content.mode
      assert_nil content.target_klass
      assert_equal 'foo', @node.name
      assert_equal 'foo', @node.version.title
    end

    should 'be able to update a template with blank format, mode or target_klass' do
      @node = secure(Node) { nodes(:notes_zafu) }
      assert @node.update_attributes('text' => 'hello', 'target_klass' => '', 'format' => '', 'mode' => '')
      @node = secure(Node) { nodes(:notes_zafu) } # reload
      content = @node

      assert_nil content.format
      assert_nil content.mode
      assert_nil content.target_klass

      assert_equal 'hello', @node.version.text
    end

  end

end