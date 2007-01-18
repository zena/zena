require File.dirname(__FILE__) + '/../test_helper'

class DocumentVersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_content
    v = versions(:water_pdf_en)
    assert_kind_of DocumentContent, v.content
    assert_equal 'water.pdf', v.content.filename
  end
  
  def test_presence_of_content
    visitor(:tiger)
    doc = secure(Document) { Document.create(:parent_id=>nodes_id(:status), :name=>'test') }
    assert_equal "can't be blank", doc.errors[:c_file]
  end
end
