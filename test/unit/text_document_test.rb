require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentTest < ZenaTestUnit
  
  def test_create_simplest
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'skiny')}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 0, doc.c_size
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'medium', :v_text=>"12345678901234567890")}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 20, doc.c_size
  end
  
  def test_create_with_file
    login(:tiger)
    next_id = Version.find(:first, :order=>"id DESC")[:id] + 1
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                              :c_file => uploaded_text('some.txt', 'stupid.jpg') ) }
    assert_equal TextDocument, doc.class
    # reload
    doc = secure(Document) { Document.find(doc[:id])}
    assert !File.exist?(doc.c_filepath), "No file created"
    assert_equal 'txt', doc.c_ext
    assert_equal 'text/plain', doc.c_content_type
    assert_equal 'stupid.txt', doc.c_filename
    assert_equal 40, doc.c_size
  end
  
  def test_content_lang
    login(:tiger)
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :v_title => 'super script', 
                                              :c_content_type => 'text/x-ruby-script')}
                                              
    assert !doc.new_record?, "Not a new record"
    assert_equal TextDocument, doc.class
    assert_equal 'ruby', doc.content_lang
    
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:wiki_skin), :v_title => 'super script', 
                                              :c_content_type => 'text/html')}
    assert_equal Template, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 'zafu', doc.content_lang
  end
end
