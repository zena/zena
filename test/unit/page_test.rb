require 'test_helper'

class PageTest < Zena::Unit::TestCase

  context 'Creating a page' do
    setup do
      login(:tiger)
    end

    should 'work with just a title' do
      assert_difference('Node.count', 1) do
        secure(Page) { Page.create(:parent_id=>nodes_id(:projects), :title=>'lazy node')}
      end
    end

    should 'allow same title' do
      wiki_title = nodes(:wiki).title
      assert_difference('Node.count', 1) do
        page = secure(Page) { Page.create(:parent_id=>nodes_id(:projects), :title => wiki_title)}
        assert_equal page.title, wiki_title
      end
    end
  end # Creating a page

  def test_custom_base_path
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal '', node.basepath
    assert_equal '', bird.basepath
    assert_equal node[:id], bird[:parent_id]
    assert node.update_attributes(:custom_base => true)
    assert_equal '18/29', node.basepath
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal '18/29', bird.basepath
  end
end
