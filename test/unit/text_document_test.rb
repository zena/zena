require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentTest < Test::Unit::TestCase
  include ZenaTestUnit

  # Replace this with your real tests.
  def test_create_simplest
    test_visitor(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'skiny')}
    assert_kind_of TextDocument, doc
    assert !doc.new_record?, "Not a new record"
  end
  
  def test_create_template
    test_visitor(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'skiny.html')}
    assert_kind_of Skin, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/html', doc.c_content_type
    assert_equal 'html', doc.c_ext
    sub = secure(Document) { Document.create(:parent_id=>doc[:id], :name=>'sub.html')}
    assert_kind_of Template, sub
    assert !sub.kind_of?(Skin)
    assert !sub.new_record?, "Not a new record"
  end
end
