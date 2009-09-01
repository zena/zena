require 'test_helper'

class TemplateVersionTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end
  def test_truth
    assert true
  end
end
