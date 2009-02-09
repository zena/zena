require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentVersionTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  
  def test_content
    v = TextDocumentVersion.new
    assert_equal TextDocumentContent, TextDocumentVersion.content_class
    assert_kind_of TextDocumentContent, v.content
  end
end
