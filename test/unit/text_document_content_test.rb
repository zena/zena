require File.dirname(__FILE__) + '/../test_helper'

class TextDocumentContentTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  def test_truth
    assert true
  end
end
