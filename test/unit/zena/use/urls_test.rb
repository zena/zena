require 'test_helper'

class UrlsTest < Zena::View::TestCase
  include Zena::Use::Urls::ViewMethods

  def host_with_port
    "foo.com:123"
  end

  def http_protocol
    'https'
  end

  attr_reader :params

  def test_zen_path
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    assert_equal '/oo', zen_path(node)
    assert_equal '/oo/project11_test.html', zen_path(node, :mode=>'test')

    login(:anon)
    node = secure!(Node) { nodes(:zena) }
    assert_equal '/en', zen_path(node)
    assert_equal '/en/project11_test.html', zen_path(node, :mode=>'test')
    node = secure!(Node) { nodes(:people) }
    assert_equal '/en/section12.html', zen_path(node)
    assert_equal '/en/section12_test.html', zen_path(node, :mode=>'test')
    assert_match %r{/tt/section12_test.11fbc.jpg}, zen_path(node, :mode=>'test', :prefix=>'tt', :format=>'jpg')
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal '/en/projects-list/Clean-Water-project', zen_path(node)
    assert_equal '/en/projects-list/Clean-Water-project_test', zen_path(node, :mode=>'test')
    node = secure!(Node) { nodes(:status) }
    assert_equal '/en/projects-list/Clean-Water-project/page22.html', zen_path(node)
    assert_equal '/en/projects-list/Clean-Water-project/page22_test.html', zen_path(node, :mode=>'test')
  end

  def test_zen_path_custom_base_with_accents
    # See also test in NodesController
    login(:lion)
    node = secure!(Node) { nodes(:cleanWater) }
    node.update_attributes(:title => 'Lignes aériennes')
    assert_equal '/oo/projects-list/Lignes-a%C3%A9riennes', zen_path(node)
    # Make sure this is parsed back correctly
    assert_match Zena::Use::Urls::ALLOWED_REGEXP, zen_path(node).split('/').last
  end

  def test_zen_path_query_params
    login(:anon)
    node = secure!(Node) { nodes(:status) }
    assert_equal '/en/projects-list/Clean-Water-project/page22.html?p=5', zen_path(node, :p => 5)
    @params = {'p' => 'Pepe', 'a' => {'b' => 'Bee'}}
    assert_equal '/en/projects-list/Clean-Water-project/page22.html?a%5Bb%5D=Bee&p=Pepe', zen_path(node, :encode_params => 'p,a')
  end

  def test_zen_path_cache_stamp
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    assert_equal '/oo/project11.11fbc.png', zen_path(node, :format => 'png')
    node = secure!(Node) { nodes(:bird_jpg) }
    assert_equal '/en/image30.11fbc.jpg', zen_path(node, :format => 'jpg')
    node = secure!(Node) { nodes(:style_css) }
    assert_equal '/en/textdocument54.11fbc.css', zen_path(node, :format => 'css')

    login(:anon)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal '/en/projects-list/Clean-Water-project.11fbc.jpg', zen_path(node, :format => 'jpg')
  end

  def test_make_cachestamp
    login(:lion)

    node = secure!(Node) { nodes(:bird_jpg) }
    base = '7f6f0'
    assert_equal base, make_cachestamp(node, 'pv')
    # update pv
    imf = Iformat.create(:name => 'pv', :width => 70, :height=> 70, :size=> 'force')
    assert !imf.new_record?
    # same hash
    assert_equal base, make_cachestamp(node, 'pv')

    assert Iformat.update(imf.id, :width => 60)
    assert_equal '14052', make_cachestamp(node, 'pv')
    assert_not_equal base, '14052'

    assert Iformat.update(imf.id, :width => 70)
    # should be the same as first
    assert_equal base, make_cachestamp(node, 'pv')
  end

  def test_zen_path_cachestamp_image_mode
    login(:ant)
    node = secure!(Node) { nodes(:bird_jpg) }
    assert_equal "/en/image30.#{make_cachestamp(node,nil)}.jpg", zen_path(node, :format => 'jpg')
    assert_equal "/en/image30_pv.#{make_cachestamp(node, 'pv')}.jpg", zen_path(node, :format => 'jpg', :mode => 'pv')
  end

  def test_zen_path_with_anchor
    login(:anon)
    assert_equal '/en/section12.html#comments', zen_path(nodes(:people), :anchor => 'comments')
  end

  def test_zen_path_asset
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/oo/project11=abcd.html", zen_path(node, :asset=>'abcd')
    node = secure!(Node) { nodes(:people) }
    assert_equal "/oo/section12=m1234.#{make_cachestamp(node,nil)}.png", zen_path(node, :asset=>'m1234', :format=>'png')

    login(:anon)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/en/project11=abcd.11fbc.png", zen_path(node, :asset=>'abcd', :format=>'png')
    node = secure!(Node) { nodes(:people) }
    assert_equal "/en/section12=kls.html", zen_path(node, :asset=>'kls')
    assert_equal "/tt/section12=foo.11fbc.jpg", zen_path(node, :mode=>'test', :prefix=>'tt', :format=>'jpg', :asset => 'foo')
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal "/en/projects-list/Clean-Water-project=kls", zen_path(node, :asset => 'kls')
    node = secure!(Node) { nodes(:status) }
    assert_equal "/en/projects-list/Clean-Water-project/page22=abcd.11fbc.png", zen_path(node, :asset => 'abcd', :format => 'png')
  end

  def test_zen_url
    login(:anon)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "https://foo.com:123/en", zen_url(node)
    assert_equal "https://foo.com:123/en/project11_test.html", zen_url(node, :mode=>'test')
  end

  def test_data_path_for_public_documents
    login(:lion)
    node = secure!(Node) { nodes(:water_pdf) }
    assert_equal "/en/projects-list/Clean-Water-project/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/oo/projects-list/Clean-Water-project/page22.html", data_path(node)

    login(:anon)
    node = secure!(Node) { nodes(:water_pdf) }
    assert_equal "/en/projects-list/Clean-Water-project/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/en/projects-list/Clean-Water-project/page22.html", data_path(node)
  end

  def test_data_path_for_non_public_documents
    login(:tiger)
    node = secure!(Node) { nodes(:water_pdf) }
    assert node.update_attributes( :rgroup_id => groups_id(:workers), :inherit => 0 )
    assert !node.public?
    assert !node.v_public?
    assert_equal "/oo/projects-list/Clean-Water-project/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/oo/projects-list/Clean-Water-project/page22.html", data_path(node)

    login(:anon)
    assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { nodes(:water_pdf) } }
  end
end
