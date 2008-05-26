require File.dirname(__FILE__) + '/../test_helper'

class SkinTest < ZenaTestUnit

  def test_name_change
    login(:lion)
    skin = secure!(Node) { nodes(:wiki_skin) }
    tmpt = secure!(Node) { nodes(:wiki_Node) }
    assert_kind_of Template, tmpt
    assert_equal 'wiki', skin.name
    assert_equal 'wiki', tmpt.c_skin_name
    skin.name = 'fun'
    assert skin.save, "Can save skin."
    tmpt = secure!(Node) { nodes(:wiki_Node) } # reload
    assert_equal 'fun', tmpt.c_skin_name
    assert_equal 'fun', secure!(Node) { nodes(:wiki_Page_changes) }.c_skin_name
  end
end