require File.dirname(__FILE__) + '/../test_helper'

class ZazenHelperTest < ZenaTestHelper
  include ApplicationHelper

  def setup
    @controllerClass = ApplicationController
    super
  end
  
  # all these additions are replaced by the traduction of 'unknown link' if the user does not have read access to the linked node.
  def test_bad_link
    assert_match %r{unknown link}, zazen('"hello":99')
  end
  
  def test_wiki_link
    login(:tiger)
    assert_equal "<p>? colors? I like <a href='http://en.wikipedia.org/wiki/Special:Search?search=yellow+mug' class='wiki'>yellow mug</a></p>", zazen("? colors? I like ?yellow mug?")
    assert_match %r{<cite>blah</cite> <cite>blih <a.*>test</a> it</cite>}, zazen('??blah?? ??blih ?test? it??')
  end
  
  def test_image_title
    preserving_files('test.host/data/jpg/20') do
      login(:tiger)
      assert_match %r{<div class='img_with_title'><img[^>]*><div class='img_title'><p>blah <a href=.*projects/cleanWater.*Clean Water.*/a></p></div></div>},
       zazen("!30/blah \"\":21!")
     assert_match %r{<div class='img_with_title'><img.*class.*pv.*><div class='img_title'><p>blah <a href=.*projects/cleanWater.*Clean Water.*/a></p></div></div>},
        zazen("!30.pv/blah \"\":21!")
     assert_match %r{<div class='img_with_title'><img.*class.*std.*><div class='img_title'><p>Photo taken from.*</p></div></div>}, zazen("!30/!")
    
    end
  end
  
  def test_make_link
    login(:tiger)
    # * ["":34] creates a link to node 34 with node's title.
    assert_equal '<p><a href="/oo/projects/cleanWater">Clean Water project</a></p>', zazen('"":21')
    # * ["title":34] creates a link to node 34 with the given title.
    assert_equal '<p><a href="/oo/projects/cleanWater">hello</a></p>', zazen('"hello":21')
    # * ["":034] if the node id starts with '0', creates a popup link.
    assert_match %r{/oo/projects/cleanWater.*window.open.*hello}, zazen('"hello":021')
  end

  def test_make_image
    preserving_files('test.host/data/jpg/14') do
      login(:tiger)
      # * [!24!] inline image 24. (default format is 'pv' defined in #ImageBuilder). Options are :
      assert_equal "<p><img src='/en/projects/cleanWater/image24_std.jpg' width='545' height='400' alt='it&apos;s a lake' class='std'/></p>", zazen('!24!')
      # ** [!024!] inline image, default format, link to full image.
      assert_equal "<p><a href='/oo/projects/cleanWater/image24.jpg'><img src='/en/projects/cleanWater/image24_std.jpg' width='545' height='400' alt='it&apos;s a lake' class='std'/></a></p>", zazen('!024!')
    end
  end

  def test_make_image_with_document
    login(:tiger)
    assert_match %r{<p><a.*href=.*oo/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' alt='pdf document' class='doc'/></a></p>}, zazen('!25!')
    assert_match %r{<p><a.*href=.*oo/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' alt='pdf document' class='doc'/></a></p>}, zazen('!025!') # same as '!25!'
    assert_match %r{<p><a.*href=.*oo/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf_pv.png' width='70' height='70' alt='pdf document' class='doc'/></a></p>}, zazen('!25.pv!')
  end

  def test_make_bad_image
    assert_match %r{unknown document}, zazen('!99!')
  end

  def test_make_image_align
    preserving_files('test.host/data/jpg/14') do
      # ** [!<.24!] or [!<24!] inline image surrounded with <p class='float_left'></p>
      assert_match %r{class='img_left'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!<.24!')
      assert_match %r{class='img_left'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!<24!')
      # ** [!>.24!] inline image surrounded with <p class='float_right'></p>
      assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!>.24!')
      assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!>24!')
      # ** [!=.24!] inline image with <p class='center'></p>
      assert_match %r{class='img_center'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!=.24!')
      assert_match %r{class='img_center'.*img.*/en/projects/cleanWater/image24_std.jpg.*class='std'}, zazen('!=24!')
    end
  end

  def test_make_iformat
    preserving_files('test.host/data/jpg/14') do
      # ** [!24.pv!] inline image transformed to format 'pv'. Formats are defined in #ImageBuilder.
      assert_match %r{.*img.*/en/projects/cleanWater/image24.jpg.*600.*440.*class='full'}, zazen('!24.full!')
      assert_match %r{.*img.*/en/projects/cleanWater/image24_tiny.jpg.*16.*16.*class='tiny'}, zazen('!24.tiny!')
    end
  end

  def test_all_options
    preserving_files('test.host/data/jpg/14') do
      # ** all the options above can be used together as in [!>.26.std!] : inline image on the right, size 'med'.
      assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_mini.jpg.*32.*32.*class='mini'}, zazen('!>24.mini!')
      assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_mini.jpg.*32.*32.*class='mini'}, zazen('!>.24.mini!')
    end
  end

  def test_make_gallery
    login(:anon)
    preserving_files('test.host/data/jpg') do
      # ** [![2,3,5]!] gallery : inline preview with javascript inline viewer
      assert_match %r{table.*gallery.*Zena.transfer.*image24_pv.jpg.*image24_std.jpg.*image30_pv.jpg.*image30_std.jpg}m, zazen('![24,30]!')
      @node = secure!(Node) { Node.find(nodes_id(:wiki)) }
      # ** [![]!] gallery with all images contained in the current node
      assert_match %r{table.*gallery.*Zena.transfer.*image30_pv.jpg.*image30_std.jpg.*image31_pv.jpg.*image31_std.jpg}m, zazen('![]!')
    end
  end

  def test_list_nodes
    preserving_files('test.host/data/jpg') do
      login(:lion)
      # * [!{7,9}!] documents listing for documents 7 and 9
      assert_match %r{table.*tr.*bird.*tr.*water}m, zazen('!{30,25}!') # water, forest
      # * [!{}!] list all documents (with images) for the current node
      @node = secure!(Node) { Node.find(nodes_id(:cleanWater))}
      assert_match %r{table.*tr.*water}m, zazen('!{}!')
      # * [!{i}!] list all images for the current node
      assert_no_match %r{water}m, (i=zazen('!{i}!'))
      # * [!{d}!] list all documents (without images) for the current node
      @node = secure!(Node) { Node.find(nodes_id(:wiki)) }
      assert_no_match %r{flower}m, (d=zazen('!{d}!'))
    end
  end

  def test_image_as_link
    preserving_files('test.host/data/jpg/14') do
      # * [!26!:37] you can use an image as the source for a link
      assert_match %r{<p><a href.*en/projects/cleanWater.*img src.*image24_std.jpg.*545.*400.*class='std'}, zazen('!24!:21')
      # * [!26!:www.example.com] use an image for an outgoing link
      assert_match %r{<p><a href.*http://www.example.com.*img src.*image24_std.jpg.*545.*400.*class='std'}, zazen('!24!:http://www.example.com')
      assert_match %r{<p><a href.*http://www.example.com.*img src.*image24_std.jpg.*545.*400.*class='std'}, zazen('!24!:www.example.com')
    end
  end

  def test_full
    preserving_files('test.host/data/jpg/14') do
      assert_match %r{class='img_left'.*href.*/en/projects/cleanWater.*window.open\(this.href\).*img src.*image24_std.jpg.*545.*400.*class='std'}, zazen('!<.24.3!:021')
    end
  end
  
  def test_empty_image_ref
    assert_equal '<p>!!</p>', zazen('!!')
    assert_equal "<p>!\n<br/>!</p>", zazen("!\n!")
    assert_equal "<p>!!!</p>", zazen('!!!')
  end
  
  def test_no_images
    preserving_files('test.host/data/jpg/20') do
      assert_match %r{salut les \[image: bird\]}, zazen('salut les !30.pv!', :images=>false)
    end
  end
  
end