require File.dirname(__FILE__) + '/../test_helper'

class TemplateTest < ZenaTestUnit
  
  def test_create_simplest
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'super.zafu')}
    assert_kind_of Template, doc
    assert doc.new_record?, "New record"
    assert doc.errors[:parent_id], "Invalid parent (section is not a skin)"
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.zafu')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.c_content_type
    assert_equal 'zafu', doc.c_ext
  end
  
  def test_create_empty_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.zafu', :c_mode => '')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'zafu', doc.c_ext
  end

  def test_create_empty_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :c_klass=>'Section') }
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/zafu', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'zafu', doc.c_ext
    assert_equal 'Section', doc.c_klass
    assert_equal 'Section', doc.name
    assert_equal 'html', doc.c_format
    assert_equal 'NPS', doc.c_tkpath
  end
  
  def test_create_with_format
    login(:tiger)
    doc = secure!(Template) { Template.create("name"=>"Node-tree", "c_format"=>"xml", "v_summary"=>"", "parent_id"=>nodes_id(:default))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'Node-tree-xml', doc.name
    assert_equal 'tree', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'Node', doc.c_klass
    assert_equal 'N', doc.c_tkpath
    assert_equal 'zafu', doc.c_ext
  end
  
  def test_create_with_file
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'skiny', 
      :c_file=>uploaded_file('some.txt', content_type="text/zafu", 'smoke'))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'skiny.zafu', doc.c_filename
    
    sub = secure!(Document) { Document.create(:parent_id=>doc[:id], :name=>'sub.html')}
    assert_kind_of Template, sub
    assert !sub.new_record?, "Not a new record"
  end
  
  def test_set_by_name
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
    assert_equal 'Project-collab-xml', doc.name
  end
  
  def test_set_by_name_without_mode
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'Project--xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
    assert_equal 'Project--xml', doc.name
  end
  
  def test_set_name_with_title
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :v_title=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
    assert_equal 'Project-collab-xml', doc.name
  end
  
  def test_set_blank_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_mode' => 'collab', 'c_klass' => 'Page', 'name' => '', 'c_format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.c_mode
    assert_equal 'html', doc.c_format
    assert_equal 'NP', doc.c_tkpath
    assert_equal 'Page', doc.c_klass
    assert_equal 'Page-collab', doc.name
  end
  
  def test_change_name
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    err doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:name => "Page-super")
    assert_equal 'super', doc.c_mode
    assert_equal 'html', doc.c_format
    assert_equal 'NP', doc.c_tkpath
    assert_equal 'Page', doc.c_klass
    assert_equal 'Page-super', doc.name
  end

  def test_change_name_not_master
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:name => "simple-thing")
    assert_nil doc.c_mode
    assert_nil doc.c_format
    assert_nil doc.c_tkpath
    assert_nil doc.c_klass
    assert_equal 'simple-thing', doc.name
  end
  
  def test_set_name_no_extension
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab')}
    assert_kind_of Template, doc
    err doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project-collab', doc.name
    assert_equal 'collab', doc.c_mode
    assert_equal 'html', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
  end
  
  def test_set_name2
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Project-collab-any-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert_nil doc.c_format
    assert_nil doc.c_tkpath
    assert_nil doc.c_klass
    assert_equal 'Project-collab-any-xml', doc.name
  end
  
  def test_set_klass
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), :name=>'Spider-man-xml',
                                             :c_klass => 'Page',
                                             :c_format => 'ical')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Page-man-ical', doc.name
    assert_equal 'man', doc.c_mode
    assert_equal 'ical', doc.c_format
    assert_equal 'NP', doc.c_tkpath
    assert_equal 'Page', doc.c_klass
  end
  
  def test_set_blank_name_not_unique
    login(:tiger)
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_mode' => '', 'c_klass' => 'Contact', 'name' => '', 'c_format' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert_equal 'html', doc.c_format
    assert_equal 'NRC', doc.c_tkpath
    assert_equal 'Contact', doc.c_klass
    assert_equal 'Contact', doc.name
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_mode' => '', 'c_klass' => 'Contact', 'name' => '', 'c_format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert_equal 'vcard', doc.c_format
    assert_equal 'NRC', doc.c_tkpath
    assert_equal 'Contact', doc.c_klass
    assert_equal 'Contact--vcard', doc.name
  end
  
  def test_update_format_updates_name
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_mode' => '', 'c_klass' => 'Contact', 'name' => '', 'c_format' => 'vcard')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert_equal 'vcard', doc.c_format
    assert_equal 'NRC', doc.c_tkpath
    assert_equal 'Contact', doc.c_klass
    assert_equal 'Contact--vcard', doc.name
    assert doc.update_attributes(:c_format => 'vcf')
    assert_equal 'vcf', doc.c_format
    assert_equal 'NRC', doc.c_tkpath
    assert_equal 'Contact', doc.c_klass
    assert_equal 'Contact--vcf', doc.name
    
  end
  
  def test_update_text
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'v_text'=>"hey", 'c_mode' => '', 'c_klass' => 'Contact', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_nil doc.c_mode
    assert doc.update_attributes('v_text'=>"ho", 'c_format'=>'html', 'c_klass'=>'Node', 'c_mode' => '')
  end
  
  def test_default_text
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_klass' => 'Contact', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{include.*Node}, doc.version.text
  end
  
  def test_default_text_Node
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_klass' => 'Node', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_match %r{xmlns.*www\.w3\.org.*body}m, doc.version.text
  end
  
  def test_default_text_other_format
    doc = secure!(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_format' => 'vcard', 'c_klass' => 'Node', 'name' => '')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.version.text.blank?
  end
  
  def test_move_bad_parent
    login(:lion)
    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }
    assert !doc.update_attributes(:parent_id => nodes_id(:collections))
    assert_equal "Invalid parent (section is not a Skin)", doc.errors[:parent_id]
  end
  
  def test_move
    login(:lion)
    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }
    tmpt_content = doc.v_content
    assert_equal 'wiki_skin', tmpt_content.skin_name
    assert doc.update_attributes(:parent_id => nodes_id(:default))
    
    doc = secure!(Template) { nodes(:wiki_Project_changes_xml_zafu) }
    tmpt_content = doc.v_content
    assert_equal 'default', tmpt_content.skin_name
  end
  
  def test_update_same_text
    login(:tiger)
    tmpt = secure(Template) { Template.create(:parent_id=>nodes_id(:default), 'c_format' => 'vcard', 'c_klass' => 'Node', 'name' => '', 'v_status' => Zena::Status[:pub], 'c_file' =>
      uploaded_file('some.txt', 'text/zafu')) }
    assert_kind_of Template, tmpt
    tmpt.send(:update_attribute_without_fuss, :updated_at, Time.gm(2006,04,11))
    assert_equal Zena::Status[:pub], tmpt.v_status
    tmpt = secure(Node) { Node.find(tmpt[:id]) }
    
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(uploaded_text('some.txt').read)
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(tmpt.c_file.read)
    assert_equal 1, tmpt.versions.count
    assert_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')
    assert tmpt.update_attributes(:c_file => uploaded_text('some.txt'))
    assert_equal 1, tmpt.versions.count
    assert_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')
    assert tmpt.update_attributes(:c_file => uploaded_text('other.txt'))
    assert_equal 2, tmpt.versions.count
    assert_not_equal '2006-04-11 00:00', tmpt.updated_at.strftime('%Y-%m-%d %H:%M')
  end
end