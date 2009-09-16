require File.dirname(__FILE__) + '/../../../../test/test_helper'

class TagsTest < Zena::Unit::TestCase

  def test_tag
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert Node.attr_public?('tag')
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
    assert_equal 'blue, sky, ugly', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue, sky, ugly', node.tag_list
  end

  def test_add_remove_tagged
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tagged => {:ugly => 'ugly', :foo => 'true', :sky => ''})
    assert_equal 'blue, foo, ugly', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue, foo, ugly', node.tag_list
  end

  def test_remove_one_tag
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => '-sky')
    assert_equal 'blue', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue', node.tag_list
  end

  def test_tagged
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    h = {"sky"=>"sky", "blue"=>"blue"}
    assert_equal h, node.tagged
  end

  def test_remove_one_tag_using_empty_value
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tagged => {:sky => ''})
    assert_equal 'blue', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue', node.tag_list
  end

  def test_remove_inexistant_tag
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => '-ugly')
    assert_equal 'blue, sky', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'blue, sky', node.tag_list
  end

  def test_add_several_tags
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => 'big, brown,socks')
    node = secure!(Node) { nodes(:status) }
    assert_equal 'big, blue, brown, sky, socks', node.tag_list
  end

  def test_remove_many_tags
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => '-sky, -blue, ugly, -foobar')
    assert_equal 'ugly', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'ugly', node.tag_list
  end

  def test_add_remove
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag => '-sky, ugly, sky, -blue, -ugly, -foobar')
    assert_equal 'sky', node.tag_list
    node = secure!(Node) { nodes(:status) }
    assert_equal 'sky', node.tag_list
  end

  def test_set_tag_list
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:tag_list => 'big, brown,socks')
    node = secure!(Node) { nodes(:status) }
    assert_equal 'big, brown, socks', node.tag_list
  end

end