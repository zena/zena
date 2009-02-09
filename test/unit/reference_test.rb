require File.dirname(__FILE__) + '/../test_helper'

class ReferenceTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
