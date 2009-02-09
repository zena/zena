require File.dirname(__FILE__) + '/../test_helper'

class SkinTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end

  def test_name_change
    login(:lion)
    skin = secure!(Node) { nodes(:wiki_skin) }
    tmpt = secure!(Node) { nodes(:wiki_Node_zafu) }
    assert_kind_of Template, tmpt
    assert_equal 'wikiSkin', skin.name
    assert_equal 'wikiSkin', tmpt.c_skin_name
    skin.name = 'fun'
    assert skin.save, "Can save skin."
    tmpt = secure!(Node) { nodes(:wiki_Node_zafu) } # reload
    assert_equal 'fun', tmpt.c_skin_name
    assert_equal 'fun', secure!(Node) { nodes(:wiki_Page_changes_zafu) }.c_skin_name
  end
end