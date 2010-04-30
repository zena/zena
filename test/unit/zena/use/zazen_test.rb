require 'test_helper'

class ZazenTest < Zena::View::TestCase
  def setup
    super
    login(:anon)
    visiting(:status)
  end

  def assert_zazen_match(css, code)
    assert_match css, zazen(code)
  end

  # all these additions are replaced by the traduction of 'unknown link' if the user does not have read access to the linked node.
  def test_bad_link
    assert_match %r{unknown link}, zazen('"hello":99')
  end

  def test_wiki_link
    assert_equal "<p>? colors? I like <a href='http://en.wikipedia.org/wiki/Special:Search?search=yellow+mug' class='wiki'>yellow mug</a></p>", zazen("? colors? I like ?yellow mug?")
    assert_match %r{<cite>blah</cite> <cite>blih <a.*>test</a> it</cite>}, zazen('??blah?? ??blih ?test? it??')
  end

  def test_image_title
    assert_match %r{<div class='img_with_title'><img[^>]*><div class='img_title'><p>blah <a href=.*projects/cleanWater.*Clean Water.*/a></p></div></div>},
    zazen("!30/blah \"\":21!")
    assert_match %r{<div class='img_with_title'><img.*class.*pv.*><div class='img_title'><p>blah <a href=.*projects/cleanWater.*Clean Water.*/a></p></div></div>},
    zazen("!30_pv/blah \"\":21!")
    assert_match %r{<div class='img_with_title'><img.*class.*std.*><div class='img_title'><p>Photo taken from.*</p></div></div>}, zazen("!30/!")

  end

  def test_make_link
    # * ["":34] creates a link to node 34 with node's title.
    assert_equal '<p><a href="/en/projects/cleanWater">Clean Water project</a></p>', zazen('"":21')
    # * ["title":34] creates a link to node 34 with the given title.
    assert_equal '<p><a href="/en/projects/cleanWater">hello</a></p>', zazen('"hello":21')
    # * ["":034] if the node id starts with '0', creates a popup link.
    assert_match %r{/en/projects/cleanWater.*window.open.*hello}, zazen('"hello":021')
  end

  def test_make_link_sharp
    assert_equal '<p><a href="#node34">hello</a></p>', zazen('"hello":34#')
    assert_equal '<p><a href="#node34">hello</a></p>', zazen('"hello":34#[id]')
    assert_equal '<p><a href="#node34">hello</a></p>', zazen('"hello":34#[zip]')
    assert_equal '<p><a href="#news">hello</a></p>', zazen('"hello":34#[node_name]')
    # * ["":34#[parent/]] if the node id starts with '0', creates a popup link.
    assert_equal '<p><a href="/en/page32.html#node34">hello</a></p>', zazen('"hello":34#[parent/]')
    assert_equal '<p><a href="/en/page32.html#node34">hello</a></p>', zazen('"hello":34#[parent/id]')
    assert_equal '<p><a href="/en/page32.html#node34">hello</a></p>', zazen('"hello":34#[parent/zip]')
    assert_equal '<p><a href="/en/page32.html#news">hello</a></p>', zazen('"hello":34#[parent/node_name]')
  end

  def test_make_image
    # * [!24!] inline image 24. (default format is 'pv' defined in #ImageBuilder). Options are :
    assert_equal "<p><img src='/en/projects/cleanWater/image24_std.jpg?929831698949' width='545' height='400' alt='it&apos;s a lake' class='std'/></p>", zazen('!24!')
    # ** [!024!] inline image, default format, link to full image.
    assert_equal "<p><a class='popup' href='/en/projects/cleanWater/image24.jpg?1144713600' target='_blank'><img src='/en/projects/cleanWater/image24_std.jpg?929831698949' width='545' height='400' alt='it&apos;s a lake' class='std'/></a></p>", zazen('!024!')
  end

  def test_make_image_with_document
    assert_match %r{<p><a.*href=.*en/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' alt='pdf document' class='doc'/></a></p>}, zazen('!25!')
    assert_match %r{<p><a.*href=.*en/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf.png' width='32' height='32' alt='pdf document' class='doc'/></a></p>}, zazen('!025!') # same as '!25!'
    assert_match %r{<p><a.*href=.*en/projects/cleanWater/document25\.pdf.*img src='/images/ext/pdf_pv.png' width='70' height='70' alt='pdf document' class='doc'/></a></p>}, zazen('!25_pv!')
  end

  def test_make_bad_image
    assert_match %r{unknown document}, zazen('!99!')
  end

  def test_make_image_align
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

  def test_make_iformat
    # ** [!24_pv!] inline image transformed to format 'pv'. Formats are defined in #ImageBuilder.
    assert_match %r{.*img.*/en/projects/cleanWater/image24.jpg.*600.*440.*class='full'}, zazen('!24_full!')
    assert_match %r{.*img.*/en/projects/cleanWater/image24_tiny.jpg.*16.*16.*class='tiny'}, zazen('!24_tiny!')
  end

  def test_all_options
    # ** all the options above can be used together as in [!>.26.std!] : inline image on the right, size 'med'.
    assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_mini.jpg.*32.*32.*class='mini'}, zazen('!>24_mini!')
    assert_match %r{class='img_right'.*img.*/en/projects/cleanWater/image24_mini.jpg.*32.*32.*class='mini'}, zazen('!>.24_mini!')
  end

  def test_make_gallery
    # ** [![2,3,5]!] gallery : inline preview with javascript inline viewer
    assert_match %r{table.*gallery.*Zena.transfer.*image24_pv.jpg.*image24_std.jpg.*image30_pv.jpg.*image30_std.jpg}m, zazen('![24,30]!')
    @node = secure!(Node) { Node.find(nodes_id(:wiki)) }
    # ** [![]!] gallery with all images contained in the current node
    assert_match %r{table.*gallery.*Zena.transfer.*image30_pv.jpg.*image30_std.jpg.*image31_pv.jpg.*image31_std.jpg}m, zazen('![]!')
  end

  def test_make_gallery_bad_zips
    @node = secure!(Node) { Node.find(nodes_id(:wiki)) }
    assert_nil secure(Node) { Node.find_by_id(999)}
    assert_nothing_raised { zazen("this ![999]!") }
  end

  def test_list_nodes
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

  def test_image_as_link
    # * [!26!:37] you can use an image as the source for a link
    assert_zazen_match "p a[@href='/en/projects/cleanWater'] img.std[@src='/en/image30_std.jpg?929831698949'][@width='440'][@height='400']", '!30!:21'
    # * [!26!:www.example.com] use an image for an outgoing link
    assert_zazen_match "p a[@href='http://www.example.com'] img.std[@src='/en/image30_std.jpg?929831698949']", '!30!:http://www.example.com'
  end

  def test_full
    assert_zazen_match "div.img_left a[@href='/en/projects/cleanWater'][@onclick*=window.open] img.std[@src='/en/projects/cleanWater/image24_std.jpg?929831698949'][@width='545'][@height='400'][@alt*=lake]", '!<.24_3!:021'
  end

  def test_empty_image_ref
    assert_equal '<p>!!</p>', zazen('!!')
    assert_equal "<p>!\n<br/>!</p>", zazen("!\n!")
    assert_equal "<p>!!!</p>", zazen('!!!')
  end

  def test_no_images
    assert_match %r{salut les \[image: bird\]}, zazen('salut les !30_pv!', :images=>false)
  end

  def test_pseudo_id
    assert_zazen_match "a[@href='/en/contact15.html'][text()='people/lion']", 'This is a "link"::lio.'
    assert_zazen_match "a[@href='/en/image30_pv.jpg?967816914293'][text()='projects/wiki/bird_pv.jpg']", 'This is a "link"::bir_pv.data.'
  end

  context 'An absolute pseudo path' do
    setup do
      login(:anon)
    end

    subject do
      '(/projects/wiki/bird)'
    end

    should 'resolve as link without using the current node' do
      assert_equal '<p>Read <a href="/en/image30.html">projects/wiki/bird</a></p>', zazen(%Q{Read "":#{subject}})
    end

    should 'resolve as image without using the current node' do
      assert_match %Q{img[@src='/en/image30_std.jpg?929831698949]}, zazen(%Q{See !#{subject}!})
    end


    context 'with mode' do
      subject do
        '(/projects/wiki/bird)_side'
      end

      should 'resolve with mode in image tag' do
        assert_equal "<p>See <img src='/en/image30_side.jpg?100321116926' width='220' height='500' alt='bird' class='side'/></p>", zazen(%Q{See !#{subject}!})
      end

      should 'resolve with mode as link' do
        assert_match %r{/en/image30_side\.html}, zazen(%Q{Read "":#{subject}})
      end

      should 'resolve with mode as link to image' do
        assert_equal "<p>Read <a href=\"/en/image30_side.html\"><img src='/en/image30_std.jpg?929831698949' width='440' height='400' alt='bird' class='std'/></a></p>", zazen(%Q{Read !30!:#{subject}})
      end

      should 'resolve with mode as link and image tag' do
        assert_equal "<p>See <a href=\"/en/image30_side.html\"><img src='/en/image30_side.jpg?100321116926' width='220' height='500' alt='bird' class='side'/></a></p>", zazen(%Q{See !:#{subject}!:#{subject}})
      end
    end
  end # An absolute pseudo path

  context 'A relative pseudo path' do
    setup do
      login(:lion)
    end

    subject do
      '(status)'
    end

    context 'with different current nodes' do
      setup do
        lion = secure!(Node) { nodes(:lion) }
        lion.update_attributes(:title => 'status', :v_status => Zena::Status[:pub])
        @people = secure!(Node) { nodes(:people) }
        @cleanWater = secure!(Node) { nodes(:cleanWater) }
      end

      should 'resolve with current node' do
        @node = @cleanWater
        assert_equal '<p>Read <a href="/oo/projects/cleanWater/page22.html">projects/cleanWater/status</a></p>', zazen(%Q{Read "":#{subject}})
        @node = @people
        assert_equal '<p>Read <a href="/oo/contact15.html">people/status</a></p>', zazen(%Q{Read "":#{subject}})
      end
    end
  end # A relative pseudo path

  def test_pseudo_id_numbers_only
    login(:lion)
    lion = secure!(Node) { nodes(:lion) }
    assert lion.update_attributes(:title => '1234', :v_status => Zena::Status[:pub])
    login(:anon)
    assert_equal '<p>This is a <a href="/en/contact15.html">people/1234</a>.</p>', zazen('This is a "link"::123.')
  end

  def test_bad_pseudo_path
    login(:lion)
    lion = secure!(Node) { nodes(:lion) }

    @node = secure!(Node) { nodes(:cleanWater) }
    assert_equal '<p>Read [(shmol) not found]</p>', zazen('Read "":(shmol)')
    assert_equal 'Read "":(shmol)', zazen('Read "":(shmol)', :translate_ids => :zip, :node => lion)
  end

  def test_translate_ids
    projects = secure!(Node) { nodes(:projects) }
    zena     = secure!(Node) { nodes(:zena) }
    assert_equal "This \"is\":33 \"a\":#{nodes_zip(:wiki)} !#{nodes_zip(:bird_jpg)}! \"link\":#{nodes_zip(:lion)}.",
           zazen('This "is":33 "a":(projects/wiki) !(projects/wiki/bird)! "link"::lio.', :translate_ids => :zip, :node => zena)

    assert_equal 'This "is":(../collections/art) "a":(wiki) !(wiki/bird)! !{(wiki/bird)}! ![(wiki/bird)]! "link":(../people/lion).',
           zazen('This "is":33 "a":(/projects/wiki) !30! !{30}! ![30]! "link"::lio.', :translate_ids => :relative_path, :node => projects)

    assert_equal "This \"is\":33 \"a\":#{nodes_zip(:wiki)} !#{nodes_zip(:bird_jpg)}! \"link\":#{nodes_zip(:lion)}.",
           zazen('This "is":(../collections/art) "a":(wiki) !(wiki/bird)! "link":(../people/lion).', :translate_ids => :zip, :node => projects)

    assert_equal "This \"is\":33 \"a\":#{nodes_zip(:wiki)} !#{nodes_zip(:bird_jpg)}! \"link\":#{nodes_zip(:lion)}.",
           zazen('This "is":(collections/art) "a":(/projects/wiki) !(/projects/wiki/bird)! "link":(people/lion).', :translate_ids => :zip, :node => zena)
  end

  def test_table_asset
    login(:tiger)
    assert_match %r{<table.*<tr.*<th>title</th.*<tr.*value}m, zazen("This is a table test:\n\n|shopping_list|")
    assert_match %r{<table.*<th>problem</th>.*<th>solution</th>.*<th>cost</th>.*<tr>.*<td>dead hard drive</td>}m, zazen("This is a table test:\n\n|problems|")
  end

  # only works if recaptcha plugin is installed
  def test_mail_hide
    login(:lion)
    assert current_site.update_attributes(:mail_hide_priv => '1234', :mail_hide_pub => '3456')
    @node = secure!(Node) { nodes(:status) }
    assert_match %r{<a href.*mailhide.recaptcha.net/d\?k=3456&.*window.open}m, zazen("This is an email [email]bob@example.com[/email].")
  end
end