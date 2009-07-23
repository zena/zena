require File.dirname(__FILE__) + '/../test_helper'

class ReferenceTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
