require File.dirname(__FILE__) + '/../test_helper'

class DocumentVersionTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  
  def test_content
    v = versions(:water_pdf_en)
    assert_equal DocumentContent, v.content_class
    assert_kind_of DocumentContent, v.content
    assert_equal 'water', v.content.name
  end
end
