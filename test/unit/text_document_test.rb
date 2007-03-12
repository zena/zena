require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentTest < ZenaTestUnit
  
  def test_callbacks_for_documents
    assert Node.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert TextDocument.read_inheritable_attribute(:validate_on_create).include?(:node_on_create)
    assert TextDocument.read_inheritable_attribute(:validate_on_update).include?(:node_on_update)
    assert TextDocument.read_inheritable_attribute(:before_validation).include?(:prepare_before_validation)
  end
  
  def test_create_simplest
    login(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'skiny')}
    assert_equal TextDocument, doc.class
    err doc
    assert !doc.new_record?, "Not a new record"
  end
  
  def test_create_with_file
    next_id = Version.find(:first, :order=>"id DESC")[:id] + 1
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                              :v_title => 'My new project',
                                              :c_file => uploaded_text('some.txt', 'stupid.jpg') ) }
    assert_equal TextDocument, doc.class
    assert !File.exist?(doc.c_filepath), "No file created"
    assert_equal 'txt', doc.c_ext
    assert_equal 'text/plain', doc.c_content_type
    assert_equal 'stupid.txt', doc.c_filename
  end
  
  def test_content_lang
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :v_title => 'super script', 
                                              :c_content_type => 'text/x-ruby-script')}

    assert !doc.new_record?, "Not a new record"
    assert_equal TextDocument, doc.class
    assert_equal 'ruby', doc.content_lang
    
    doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :v_title => 'super script', 
                                              :c_content_type => 'text/html')}
    assert_equal Skin, doc.class
    assert_equal 'zafu', doc.content_lang
  end
end
