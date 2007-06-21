require File.dirname(__FILE__) + '/../test_helper'

class TemplateTest < ZenaTestUnit
  
  def test_create_simplest
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'super.html')}
    assert_kind_of Template, doc
    assert doc.new_record?, "New record"
    assert doc.errors[:parent_id], "Invalid parent (section is not a skin)"
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'super.html')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_equal 'html', doc.c_ext
  end
  
  def test_create_empty_mode
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:default), :name=>'super.html', :c_mode => '')}
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'html', doc.c_ext
  end

  def test_create_empty_name
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:default), :c_klass=>'Section') }
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_nil doc.c_mode
    assert_equal 'html', doc.c_ext
    assert_equal 'Section', doc.c_klass
    assert_equal 'Section', doc.name
  end
  
  def test_create_with_format
    login(:tiger)
    doc = secure(Template) { Template.create("name"=>"Node_tree", "c_format"=>"html", "c_mode"=>"tree", "c_klass"=>"Node", "v_summary"=>"", "parent_id"=>nodes_id(:default))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_equal 'html', doc.c_ext
  end
  
  def test_create_with_file
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:layout), :name=>'skiny', 
      :c_file=>uploaded_file('some.txt', content_type="text/html", 'smoke'))}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_equal 'html', doc.c_ext
    assert_equal 'skiny.html', doc.c_filename
    
    sub = secure(Document) { Document.create(:parent_id=>doc[:id], :name=>'sub.html')}
    assert_kind_of Template, sub
    assert !sub.new_record?, "Not a new record"
  end
  
  def test_set_name
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project_collab.xml.html')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project_collab.xml', doc.name
    assert_equal 'collab', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
  end

  def test_set_name_with_title
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :v_title=>'Project_collab.xml.html')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project_collab.xml', doc.name
    assert_equal 'collab', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
  end
  
  def test_change_name
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project_collab.xml.html')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert doc.update_attributes(:name => "Page_super")
    assert_equal 'Page_super', doc.name
    assert_equal 'super', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NP', doc.c_tkpath
    assert_equal 'Page', doc.c_klass
  end
  
  def test_set_name_no_extension
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project_collab')}
    assert_kind_of Template, doc
    err doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project_collab', doc.name
    assert_equal 'collab', doc.c_mode
    assert_equal 'html', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
  end
  
  def test_set_name2
    login(:tiger)
    doc = secure(Template) { Template.create(:parent_id=>nodes_id(:layout), :name=>'Project_collab_any.xml.html')}
    assert_kind_of Template, doc
    assert !doc.new_record?, "Saved"
    assert_equal 'Project_collab_any.xml', doc.name
    assert_equal 'collab_any', doc.c_mode
    assert_equal 'xml', doc.c_format
    assert_equal 'NPP', doc.c_tkpath
    assert_equal 'Project', doc.c_klass
  end
end