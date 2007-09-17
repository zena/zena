require File.dirname(__FILE__) + '/../test_helper'

class TemplateTest < ZenaTestUnit
  
  def test_create_simplest
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'super.zafu')}
    assert_kind_of Template, doc
    assert doc.new_record?, "New record"
    assert doc.errors[:parent_id], "Invalid parent (section is not a skin)"
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'super.zafu')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/x-zafu-script', doc.c_content_type
    assert_equal 'zafu', doc.c_ext
  end
  
  def test_create_empty_mode
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.zafu', :c_mode => '')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/x-zafu-script', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'zafu', doc.c_ext
  end

  def test_create_empty_name
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:default), :c_klass=>'Section') }
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/x-zafu-script', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'zafu', doc.c_ext
    assert_equal 'Section', doc.c_klass
    assert_equal 'Section', doc.name
    assert_equal 'html', doc.c_format
    assert_equal 'NPS', doc.c_tkpath
  end
  
  def test_create_with_format
    login(:tiger)
    doc = secure(Template) { Template.create("name"=>"Node-tree", "c_format"=>"xml", "v_summary"=>"", "parent_id"=>nodes_id(:default))}
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
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'skiny', 
      :c_file=>uploaded_file('some.txt', content_type="text/x-zafu-script", 'smoke'))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'skiny.zafu', doc.c_filename
    
    sub = secure(Document) { Document.create(:parent_id=>doc[:id], :name=>'sub.html')}
    assert_kind_of Template, sub
    assert !sub.new_record?, "Not a new record"
  end
  
  def test_set_by_name
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'Project-collab-xml.zafu')}
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
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'Project--xml.zafu')}
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
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :v_title=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'collab', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
    assert_equal 'Project-collab-xml', doc.name
  end
  
  def test_change_name
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project-collab-xml.zafu')}
    assert_kind_of Template, doc
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
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project-collab-xml.zafu')}
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
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project-collab')}
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
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project-collab-any-xml.zafu')}
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
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Spider-man-xml',
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
    
end