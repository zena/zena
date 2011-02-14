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

    should 'remove extension from title' do
      assert_equal 'Project-collab-xml', subject.title
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

      context 'with a capitalized title' do
        subject do
          secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Project.zafu') }
        end

        should 'create a new Template' do
          assert_difference('Node.count', 1) do
            assert_kind_of Template, subject
          end
        end

        should 'create a new template index entry' do
          assert_difference('IdxTemplate.count', 1) do
            subject
          end
        end

        should 'use title as target class' do
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
          secure(Document) { Document.create(:parent_id => nodes_id(:default), :title => 'foo.zafu') }
        end

        should 'create a new Template' do
          assert_difference('Node.count', 1) do
            assert !subject.new_record?
            assert_kind_of Template, subject
          end
        end

        should 'not create a new template index entry' do
          assert_difference('IdxTemplate.count', 0) do
            subject
          end
        end

        should 'set content_type' do
          assert_equal 'text/zafu', subject.content_type
        end

        should 'remove extension from title' do
          assert_equal 'foo', subject.title
        end
      end

      context 'with a blank mode' do
        subject do
          secure(Document) { Document.create(:parent_id => nodes_id(:default), :title => 'super.zafu', :mode => '') }
        end

        should 'not complain' do
          assert !subject.new_record?
          assert_nil subject.mode
        end
      end # with a blank mode

      context 'with a blank title' do
        subject do
          secure(Template) { Template.create(:parent_id=>nodes_id(:default), :target_klass => 'Section') }
        end

        should 'use target_klass as title' do
          assert !subject.new_record?
          assert_equal 'Section', subject.title
        end
      end # with a blank title

      context 'with a format' do
        subject do
          secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node-tree', :format => 'xml') }
        end

        should 'use format in title' do
          assert !subject.new_record?
          assert_equal 'Node-tree-xml', subject.title
        end
      end # with a blank title

      context 'with a special mode' do
        subject do
          secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node', :mode => '+edit') }
        end

        should 'use mode in title' do
          assert !subject.new_record?
          assert_equal 'Node-+edit', subject.title
        end
        
        context 'in the title' do
          subject do
            secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node-+index') }
          end

          should 'description' do
            assert_difference('Template.count', 1) do
              assert_equal '+index', subject.mode
            end
          end
        end # in the title
        
      end # with a special mode

      context 'with class format and mode in title' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:default), :title => 'Project-collab-xml.zafu')}
        end

        should_set_target_class_mode_and_format
      end # with class format and mode in title

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

        should 'use title for title' do
          assert_equal 'skiny', subject.title
        end
      end # with a file

      context 'with an html extension' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:default), :title => 'sub.html')}
        end

        should 'create a Template' do
          assert !subject.new_record?
          assert_kind_of Template, subject
        end
      end # with an html extension

      context 'not in a Skin section' do
        subject do
          secure!(Document) { Document.create(:parent_id => nodes_id(:cleanWater), :title => 'super.zafu')}
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
          assert_difference('IdxTemplate.count', -1) do
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
          assert_equal nodes_id(:wikiSkin), IdxTemplate.find_by_node_id(subject.id).skin_id
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
          index = IdxTemplate.find_by_node_id(subject.id)
          assert_equal nodes_id(:default), index.skin_id
          assert_equal 'html', index.format
          assert_nil index.mode
          assert_equal 'NPP', index.tkpath
        end
      end
    end # updating a template
  end # A visitor with drive access


  def test_set_by_title_without_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :title => 'Project--xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.title
  end


  def test_set_blank_title
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => 'collab', 'target_klass' => 'Page', 'title' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-collab', doc.title
  end

  def test_change_title
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:title => "Page-super")
    assert_equal 'super', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
    assert_equal 'Page-super', doc.title
  end

  def test_update_title_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:mode => "", :title=> "Project-collab-xml")
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project--xml', doc.title
    assert_equal 'Project--xml', doc.title
  end

  def test_update_blank_mode
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.mode
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:mode => "", :title => "Project-collab-xml") # name does not change, only mode is updated
    assert_nil doc.mode
    assert_equal 'xml', doc.format
    assert_equal 'Project', doc.target_klass
    assert_equal 'Project--xml', doc.title
    assert_equal 'Project--xml', doc.title
  end

  def test_cannot_change_title_not_master
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    doc = secure!(Node) { Node.find(doc[:id]) } # reload
    assert doc.update_attributes(:title => "simple-thing", :v_status => Zena::Status[:pub])
    assert_nil doc.target_klass
    assert_nil doc.mode
    assert_nil doc.format
    assert_nil doc.tkpath
    assert_equal 'simple-thing', doc.title
  end

  def test_set_title_no_extension
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Project-collab')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project-collab', doc.title
    assert_equal 'collab', doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NPP', doc.tkpath
    assert_equal 'Project', doc.target_klass
  end

  def test_set_target_klass
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :title => 'Spider-man-xml',
                                             :target_klass => 'Page',
                                             :format => 'ical')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Page-man-ical', doc.title
    assert_equal 'man', doc.mode
    assert_equal 'ical', doc.format
    assert_equal 'NP', doc.tkpath
    assert_equal 'Page', doc.target_klass
  end

  def test_set_blank_title_not_unique
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'title' => '', 'format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'html', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact', doc.title
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'title' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcard', doc.title
  end

  def test_update_format_updates_title
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'mode' => '', 'target_klass' => 'Contact', 'title' => '', 'format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.mode
    assert_equal 'vcard', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcard', doc.title
    assert doc.update_attributes(:format => 'vcf')
    assert_equal 'vcf', doc.format
    assert_equal 'NRC', doc.tkpath
    assert_equal 'Contact', doc.target_klass
    assert_equal 'Contact--vcf', doc.title
  end

  def test_default_text_Node
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'target_klass' => 'Node', 'title' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{xmlns.*www\.w3\.org.*body}m, doc.text
  end

  def test_default_text_other_format
    login(:lion)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'format' => 'vcard', 'target_klass' => 'Node', 'title' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.text.blank?
  end



end