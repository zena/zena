require 'test_helper'

class TextDocumentVersionTest < Zena::Unit::TestCase

  def test_content
    v = TextDocumentVersion.new
    assert_equal TextDocumentContent, TextDocumentVersion.content_class
    assert_kind_of TextDocumentContent, v.content
  end

  def test_change_css_should_parse_assets
    login(:tiger)
    node = secure(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg) }
    b_at = bird.updated_at
    assert bird.update_attributes(:parent_id => node[:parent_id])
    Zena::Db.set_attribute(bird, :updated_at, b_at)
    css =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('bird.jpg') }
    #pv     { background:url('bird_pv.jpg') }
    #footer { background:url('/projects/wiki/flower.jpg') }
    #no_stamp { background:url('/en/image30_pv.jpg?100001001345') }
    END_CSS
    node.update_attributes(:v_text => css)
    parsed_css =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('/en/image30.jpg?1144713600') }
    #pv     { background:url('/en/image30_pv.jpg?967816914293') }
    #footer { background:url('/en/image31.jpg?1144713600') }
    #no_stamp { background:url('/en/image30_pv.jpg?967816914293') }
    END_CSS
    assert_equal parsed_css, node.version.text
    node = secure(Node) { nodes(:style_css) }
    assert_equal parsed_css, node.version.text
  end
end
