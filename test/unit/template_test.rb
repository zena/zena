require 'test_helper'

class TemplateTest < Zena::Unit::TestCase

  def self.should_set_target_class_mode_and_format
    should 'create a Template' do
      assert !subject.new_record?
      assert_kind_of Template, subject
    end

    should 'extract mode' do
      assert_equal 'collab', subject.mode
    end

    should 'extract format' do
      assert_equal 'xml', subject.format
    end

    should 'extract target_klass' do
      assert_equal 'NPP', subject.tkpath
      assert_equal 'Project', subject.target_klass
    end

    should 'remove extension from node_name' do
      assert_equal 'Project-collab-xml', subject.node_name
    end
    
    should 'set extension to zafu' do
      assert_equal 'zafu', subject.prop['ext']
    end
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

    context 'creating a template' do

      context 'with a capitalized node_name' do
        subject do
          secure(Template) { Template.create(:parent_id => nodes_id(:default), :node_name => 'Project.zafu') }
        end

        should 'create a new Template' do
          assert_difference('Node.count', 1) do
            assert_kind_of Template, subject
          end
        end

        should 'create a new template index entry' do
          assert_difference('TemplateIndex.count', 1) do
            subject
          end
        end

        should 'use node_name as target class' do
          assert_equal 'Project', subject.target_klass
        end

        should 'set content_type' do
          assert_equal 'text/zafu', subject.content_type
        end

        should 'set a default text' do
          assert_match %r{include.*Node}, subject.text
        end
      end

      context 'with minimal arguments' do
        subject do
          secure(Document) { Document.create(:parent_id => nodes_id(:default), :node_name => 'foo.zafu') }
        end

        should 'create a new Template' do
          assert_difference('Node.count', 1) do
            assert !subject.new_record?
            assert_kind_of Template, subject
          end
        end

        should 'not create a new template index entry' do
          assert_difference('TemplateIndex.count', 0) do
            subject
          end
        end

        should 'set content_type' do
          assert_equal 'text/zafu', subject.content_type
        end

        should 'remove extension from node_name' do
          assert_equal 'foo', subject.title
          assert_equal 'foo', subject.node_name
        end
      end

      context 'with a blank mode' do
        subject do
          secure(Document) { Document.create(:parent_id => nodes_id(:default), :node_name => 'super.zafu', :mode => '') }
        end

        should 'not complain' do
          assert !subject.new_record?
          assert_nil subject.mode
        end
      end # with a blank mode

      context 'with a blank node_name' do
        subject do
          secure(Template) { Template.create(:parent_id=>nodes_id(:default), :target_klass => 'Section') }
        end

        should 'use target_klass as node_name' do
          assert !subject.new_record?
          assert_equal 'Section', subject.node_name
        end
      end # with a blank node_name

      context 'with a format' do
        subject do
          secure(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Node-tree', :format => 'xml') }
        end

        should 'use format in node_name' do
          assert !subject.new_record?
          assert_equal 'Node-tree-xml', subject.node_name
        end
      end # with a blank node_name

      context 'with class format and mode in title' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:default), :title => 'Project-collab-xml.zafu')}
        end # with class format and mode in title

        should_set_target_class_mode_and_format
      end

      context 'with class format and mode in node_name' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:default), :node_name => 'Project-collab-xml.zafu')}
        end

        should_set_target_class_mode_and_format
      end # with class format and mode in node_name

      context 'with a file' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:default),
            :title     => 'skiny',
            :file      => uploaded_fixture('some.txt', 'text/zafu', 'smoke'))}
        end

        should 'build a template from content_type' do
          assert !subject.new_record?
          assert_kind_of Template, subject
        end

        should 'use title for node_name' do
          assert_equal 'skiny', subject.node_name
        end
      end # with a file

      context 'with an html extension' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:default), :node_name => 'sub.html')}
        end

        should 'create a Template' do
          assert !subject.new_record?
          assert_kind_of Template, subject
        end
      end # with an html extension

      context 'not in a Skin section' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:cleanWater), :node_name => 'super.zafu')}
        end

        should 'return an error on parent' do
          assert subject.new_record?
          assert_equal 'invalid (section is not a Skin)', subject.errors[:parent_id]
        end
      end # not in a Skin section
    end # creating a template

    context 'updating a template' do
      context 'without mode format or target_klass' do
        subject do
          secure(Node) { nodes(:notes_zafu) }
        end

        should 'not alter type with blank format, mode or target_klass' do
          assert subject.update_attributes('text' => 'hello', 'target_klass' => '', 'format' => '', 'mode' => '')
          assert_nil subject.format
          assert_nil subject.mode
          assert_nil subject.target_klass
          assert_equal 'hello', subject.text
        end
      end # without mode format or target_klass

      context 'with target_klass' do
        subject do
          secure(Node) { nodes(:Project_zafu) }
        end

        should 'destroy index if target_klass is removed' do
          assert_difference('TemplateIndex.count', -1) do
            assert subject.update_attributes(:target_klass => '')
          end
        end
      end # with target_klass

      context 'by moving it' do
        subject do
          secure(Node) { nodes(:Project_zafu) }
        end

        should 'return an error on parent if section is not a Skin' do
          assert !subject.update_attributes(:parent_id => nodes_id(:collections) )
          assert_equal 'invalid (section is not a Skin)', subject.errors[:parent_id]
        end

        should 'update index' do
          assert subject.update_attributes(:parent_id => nodes_id(:wikiSkin) )
          assert_equal nodes_id(:wikiSkin), TemplateIndex.find_by_node_id(subject.id).skin_id
        end
      end # by moving it

      context 'with a file' do
        subject do
          secure(Node) { nodes(:Project_zafu) }
        end

        should 'use file content as text' do
          assert subject.update_attributes(:file => uploaded_fixture('some.txt', 'text/zafu'))
          assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(uploaded_text('some.txt').read)
          assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(subject.file.read)
          assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(subject.text)
        end

        should 'not create a new version on same text' do
          assert subject.update_attributes(:file => uploaded_fixture('some.txt', 'text/zafu'), :v_status => Zena::Status[:pub])
          assert_difference('Version.count', 0) do
            assert subject.update_attributes(:file => uploaded_fixture('some.txt', 'text/zafu'), :v_status => Zena::Status[:pub])
          end
        end
      end # with a file

      context 'by changing text' do
        subject do
          secure(Node) { nodes(:Project_zafu) }
        end

        should 'not alter index' do
          assert subject.update_attributes('text' => 'God is just an abbreviation for Goddess')
          index = TemplateIndex.find_by_node_id(subject.id)
          assert_equal nodes_id(:default), index.skin_id
          assert_equal 'html', index.format
          assert_nil index.mode
          assert_equal 'NPP', index.tkpath
        end
      end
    end # updating a template
  end # A visitor with drive access


  def test_set_by_node_name_without_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :node_name => 'Project--xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.node_name
  end


  def test_set_blank_node_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => 'collab', 'target_klass' => 'Page', 'node_name' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-collab', doc.node_name
  end

  def test_change_node_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:node_name => "Page-super")
    assert_equal 'super', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-super', doc.node_name
  end

  def test_update_title_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:mode => "", :title=> "Project-collab-xml")
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project--xml', doc.node_name
    assert_equal 'Project--xml', doc.title
  end

  def test_update_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:mode => "", :node_name => "Project-collab-xml") # name does not change, only mode is updated
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.node_name
    assert_equal 'Project--xml', doc.title
  end

  def test_cannot_change_node_name_not_master
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:node_name => "simple-thing", :v_status => Zena::Status[:pub])
    assert_nil doc.target_klass
    assert_nil doc.mode
    assert_nil doc.format
    assert_nil doc.tkpath
    assert_equal 'Project-collab-xml', doc.node_name
  end

  def test_set_node_name_no_extension
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Project-collab')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project-collab', doc.node_name
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
  end

  def test_set_target_klass
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :node_name => 'Spider-man-xml',
                                             :target_klass => 'Page',
                                             :format => 'ical')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Page-man-ical', doc.node_name
    assert_equal 'man', doc.mode
    assert_equal 'ical', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
  end

  def test_set_blank_node_name_not_unique
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'BaseContact', 'node_name' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'BaseContact', doc.target_klass
    assert_equal 'BaseContact', doc.node_name
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'BaseContact', 'node_name' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'BaseContact', doc.target_klass
    assert_equal 'BaseContact--vcard', doc.node_name
  end

  def test_update_format_updates_node_name
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'BaseContact', 'node_name' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'BaseContact', doc.target_klass
    assert_equal 'BaseContact--vcard', doc.node_name
    assert doc.update_attributes(:format => 'vcf')
    assert_equal 'vcf', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'BaseContact', doc.target_klass
    assert_equal 'BaseContact--vcf', doc.node_name
  end

  def test_default_text_Node
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'target_klass' => 'Node', 'node_name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{xmlns.*www\.w3\.org.*body}m, doc.text
  end

  def test_default_text_other_format
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'format' => 'vcard', 'target_klass' => 'Node', 'node_name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.text.blank?
  end



end