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
end