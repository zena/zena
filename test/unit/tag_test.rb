require File.dirname(__FILE__) + '/../test_helper'

class CollectorTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_pages
    visitor(:tiger)
    tag = secure(Node) { nodes(:art) }
    pages = tag.pages
    assert_equal 2, pages.size
    assert_equal 'cleanWater', pages[0].name
    child = secure(Page) { Page.create(:parent_id=>tag[:id], :name=>'a_child') }
    assert !child.new_record?, "Not a new record"
    tag = secure(Node) { nodes(:art) }
    pages = tag.pages
    assert_equal 3, pages.size
    assert_equal 'a_child', pages[0].name
  end
  
  def test_documents
    visitor(:tiger)
    doc = secure(Node) { nodes(:water_pdf) }
    doc.tag_ids = [nodes_id(:art)]
    assert doc.save, "Can save"
    tag = secure(Node) { nodes(:art) }
    assert_equal 2, tag.pages.size
    assert_equal 1, tag.documents.size
    assert_equal 'water', tag.documents[0].name
  end
end
