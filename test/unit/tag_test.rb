require File.dirname(__FILE__) + '/../test_helper'

class CollectorTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_pages
    visitor(:tiger)
    tag = secure(Item) { items(:art) }
    pages = tag.pages
    assert_equal 2, pages.size
    assert_equal 'cleanWater', pages[0].name
    child = secure(Page) { Page.create(:parent_id=>tag[:id], :name=>'a_child') }
    assert !child.new_record?, "Not a new record"
    tag = secure(Item) { items(:art) }
    pages = tag.pages
    assert_equal 3, pages.size
    assert_equal 'a_child', pages[0].name
  end
  
  def test_documents
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    doc.tag_ids = [items_id(:art)]
    assert doc.save, "Can save"
    tag = secure(Item) { items(:art) }
    assert_equal 2, tag.pages.size
    assert_equal 1, tag.documents.size
    assert_equal 'water', tag.documents[0].name
  end
end
