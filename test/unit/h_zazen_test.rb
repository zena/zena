require File.dirname(__FILE__) + '/../test_helper'

class ApplicationHelperTest < Test::Unit::TestCase
  include ZenaTestHelper
  include ApplicationHelper

  def setup
    @controllerClass = ApplicationController
    super
  end
  
  def test_code
    assert_equal "\\QUOTE\\citation\\QUOTE\\\\DDOT\\ cool\\EXCLAM\\", zazen_escape('"citation": cool!')
    assert_equal '"citation": cool!', zazen_unescape("\\QUOTE\\citation\\QUOTE\\\\DDOT\\ cool\\EXCLAM\\")
    assert_match %r{<code>"":1</code>}, zazen('@"":1@')
    assert_match %r{<code>"":1</code>}, zazen('blah @"":1@')
    assert_match %r{<code>"":1</code>}, zazen('blah @"":1@ blah')
    assert_match %r{some@email.net.*my@name.com}, zazen('some@email.net my@name.com')
  end
  
  # all these additions are replaced by the traduction of 'unknown link' if the user does not have read access to the linked node.
  def test_bad_link
    assert_match %r{unknown link}, zazen('"hello":99')
  end
  
  def test_wiki_link
    login(:tiger)
    assert_equal "<p>? colors? I like <a href='http://en.wikipedia.org/wiki/Special:Search?search=yellow+mug' class='wiki'>yellow mug</a></p>", zazen("? colors? I like ?yellow mug?")
  end
  
  def test_make_link
    login(:tiger)
    # * ["":34] creates a link to node 34 with node's title.
    assert_equal '<p><a href="/oo/projects/cleanWater">Clean Water project</a></p>', zazen('"":11')
    # * ["title":34] creates a link to node 34 with the given title.
    assert_equal '<p><a href="/oo/projects/cleanWater">hello</a></p>', zazen('"hello":11')
    # * ["":034] if the node id starts with '0', creates a popup link.
    assert_match %r{/oo/projects/cleanWater.*window.open.*hello}, zazen('"hello":011')
  end

  def test_make_image
    preserving_files('/data/test/jpg/14') do
      login(:tiger)
      # * [!14!] inline image 14. (default format is 'pv' defined in #ImageBuilder). Options are :
      assert_equal "<p><img src='/data/jpg/14/lake-std.jpg' width='545' height='400' class='std'/></p>", zazen('!14!')
      # ** [!014!] inline image, default format, link to full image.
      assert_equal "<p><a href='/data/jpg/14/lake.jpg'><img src='/data/jpg/14/lake-std.jpg' width='545' height='400' class='std'/></a></p>", zazen('!014!')
    end
  end

  def test_make_image_with_document
    login(:tiger)
    assert_match %r{<p><a.*href=.*data/pdf/15/water\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' class='doc'/></a></p>}, zazen('!15!')
    assert_match %r{<p><a.*href=.*data/pdf/15/water\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' class='doc'/></a></p>}, zazen('!015!') # same as '!15!'
    assert_match %r{<p><a.*href=.*data/pdf/15/water\.pdf.*img src='/images/ext/pdf-pv.png' width='80' height='80' class='pv'/></a></p>}, zazen('!15.pv!')
  end

  def test_make_bad_image
    assert_match %r{unknown document}, zazen('!99!')
  end

  def test_make_image_align
    preserving_files('/data/test/jpg/14') do
      # ** [!<.14!] or [!<14!] inline image surrounded with <p class='float_left'></p>
      assert_match %r{class='img_left'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!<.14!')
      assert_match %r{class='img_left'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!<14!')
      # ** [!>.14!] inline image surrounded with <p class='float_right'></p>
      assert_match %r{class='img_right'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!>.14!')
      assert_match %r{class='img_right'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!>14!')
      # ** [!=.14!] inline image with <p class='center'></p>
      assert_match %r{class='img_center'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!=.14!')
      assert_match %r{class='img_center'.*img.*/data/jpg/14/lake-std.jpg.*class='std'}, zazen('!=14!')
    end
  end

  def test_make_image_format
    preserving_files('/data/test/jpg/14') do
      # ** [!14.pv!] inline image transformed to format 'pv'. Formats are defined in #ImageBuilder.
      assert_match %r{.*img.*/data/jpg/14/lake.jpg.*600.*440.*class='full'}, zazen('!14.full!')
      assert_match %r{.*img.*/data/jpg/14/lake-tiny.jpg.*15.*15.*class='tiny'}, zazen('!14.tiny!')
    end
  end

  def test_all_options
    preserving_files('/data/test/jpg/14') do
      # ** all the options above can be used together as in [!>.26.std!] : inline image on the right, size 'med'.
      assert_match %r{class='img_right'.*img.*/data/jpg/14/lake-mini.jpg.*40.*40.*class='mini'}, zazen('!>14.mini!')
      assert_match %r{class='img_right'.*img.*/data/jpg/14/lake-mini.jpg.*40.*40.*class='mini'}, zazen('!>.14.mini!')
    end
  end

  def test_make_gallery
    preserving_files('/data/test/jpg') do
      # ** [![2,3,5]!] gallery : inline preview with javascript inline viewer
      assert_match %r{table.*gallery.*Zena.transfer.*lake-pv.jpg.*lake-std.jpg.*bird-pv.jpg.*bird-std.jpg}m, zazen('![14,20]!')
      @node = secure(Node) { Node.find(nodes_id(:wiki)) }
      # ** [![]!] gallery with all images contained in the current node
      assert_match %r{table.*gallery.*Zena.transfer.*bird-pv.jpg.*bird-std.jpg.*flower-pv.jpg.*flower-std.jpg}m, zazen('![]!')
    end
  end

  def test_list_nodes
    preserving_files('/data/test/jpg') do
      login(:lion)
      # * [!{7,9}!] documents listing for documents 7 and 9
      assert_match %r{table.*tr.*bird.*tr.*water}m, zazen('!{20,15}!') # water, forest
      # * [!{}!] list all documents (with images) for the current node
      @node = secure(Node) { Node.find(nodes_id(:cleanWater))}
      assert_match %r{table.*tr.*water}m, zazen('!{}!')
      # * [!{i}!] list all images for the current node
      assert_no_match %r{water}m, (i=zazen('!{i}!'))
      # * [!{d}!] list all documents (without images) for the current node
      @node = secure(Node) { Node.find(nodes_id(:wiki)) }
      assert_no_match %r{flower}m, (d=zazen('!{d}!'))
    end
  end

  def test_image_as_link
    preserving_files('/data/test/jpg/14') do
      # * [!26!:37] you can use an image as the source for a link
      assert_match %r{<p><a href.*en/projects/cleanWater.*img src.*lake-std.jpg.*545.*400.*class='std'}, zazen('!14!:11')
      # * [!26!:www.example.com] use an image for an outgoing link
      assert_match %r{<p><a href.*http://www.example.com.*img src.*lake-std.jpg.*545.*400.*class='std'}, zazen('!14!:http://www.example.com')
      assert_match %r{<p><a href.*http://www.example.com.*img src.*lake-std.jpg.*545.*400.*class='std'}, zazen('!14!:www.example.com')
    end
  end

  def test_full
    preserving_files('/data/test/jpg/14') do
      assert_match %r{class='img_left'.*href.*/en/projects/cleanWater.*window.open\(this.href\).*img src.*lake-std.jpg.*545.*400.*class='std'}, zazen('!<.14.3!:011')
    end
  end
  
  def test_empty_image_ref
    assert_equal '<p>!!</p>', zazen('!!')
    assert_equal "<p>!\n!</p>", zazen("!\n!")
    assert_equal "<p>!!!</p>", zazen('!!!')
  end
  
  def test_no_images
    preserving_files('/data/test/jpg/20') do
      assert_match %r{salut les \[image\]}, zazen('salut les !20.pv!', :images=>false)
    end
  end
  
end