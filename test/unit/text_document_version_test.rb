require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentVersionTest < ZenaTestUnit
  
  def test_content
    v = TextDocumentVersion.new
    assert_equal TextDocumentContent, v.content_class
    assert_kind_of TextDocumentContent, v.content
  end
end
