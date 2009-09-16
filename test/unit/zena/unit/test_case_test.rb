require 'test_helper'

class TestCaseTest < Zena::Unit::TestCase
  def test_login
    login(:ant)
    assert_equal users_id(:ant), visitor.id
  end

  def test_nodes_id
    assert_equal nodes(:zena)[:id], nodes_id(:zena)
  end
end