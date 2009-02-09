require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentContentTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end

  def test_truth
    assert true
  end
end
