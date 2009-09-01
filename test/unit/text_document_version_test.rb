require 'test_helper'

class TextDocumentVersionTest < Zena::Unit::TestCase
  
  def test_content
    v = TextDocumentVersion.new
    assert_equal TextDocumentContent, TextDocumentVersion.content_class
    assert_kind_of TextDocumentContent, v.content
  end
end
