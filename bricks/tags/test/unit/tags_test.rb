require File.dirname(__FILE__) + '/../../../../test/test_helper'

class TagsTest < ZenaTestUnit

  def test_tag
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.safe_attribute?('tag')
  end
  
  def test_tag_list
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue, sky', node.tag_list
  end
  
  def test_add_one_tag
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => 'ugly')
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue, ugly, sky', node.tag_list
  end
    
end