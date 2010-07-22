require 'test_helper'

class HtmlTagsTest < Zena::View::TestCase
  def setup
    super
    login(:lion)
    visiting(:cleanWater)
  end

  context 'A logged in user' do
    setup do
      login(:lion)
      visiting(:cleanWater)
      I18n.locale = 'en'
    end

    context 'with an image' do
      subject do
        visiting(:bird_jpg)
      end

      context 'on img_tag' do
        should 'render an image tag' do
          assert_match 'img', img_tag(subject)
        end

        should 'append timestamp' do
          assert_match %r{\?1144713600}, img_tag(subject)
        end

        should 'use IFormat for timestamp' do
          assert_match %r{\?967816914293}, img_tag(subject, :mode => 'pv')
        end

        should 'set class from mode' do
          assert_match 'img.pv', img_tag(subject, :mode => 'pv')
          assert_match 'img.full', img_tag(subject)
        end

        should 'use passed id' do
          assert_match 'img#yo', img_tag(subject, :mode=>nil, :id=>'yo')
        end

        should 'use passed id and class' do
          assert_match 'img#yo.super', img_tag(subject, :mode=>'pv', :id=>'yo', :class=>'super')
        end

        should 'use alt' do
          assert_match %r{alt=.super man.}, img_tag(subject, :mode=>'side', :alt=>'super man')
        end
      end # on img_tag
    end # with an image

    context 'with a document' do
      subject do
        visiting(:water_pdf)
      end

      context 'on img_tag' do
        should 'render an image tag' do
          assert_match 'img', img_tag(subject)
        end

        should 'show a static asset from type' do
          assert_match %r{/images/ext/pdf.png}, img_tag(subject)
        end

        should 'use mode on static asset' do
          assert_match %r{/images/ext/pdf_pv.png}, img_tag(subject, :mode => 'pv')
        end

        should 'set class to doc' do
          assert_match 'img.doc', img_tag(subject)
        end
      end # on img_tag
    end # with a document

    {
      'basecontact' => :lake,
      'project' => :cleanWater,
      'post'    => :opening,
      'tag'     => :art,
    }.each do |klass, sym|
      context "with a #{klass}" do
        subject do
          secure!(Node) { nodes(sym) }
        end

        context 'on img_tag' do
          should 'render an image tag' do
            assert_match 'img', img_tag(subject)
          end

          should 'show a static asset from type' do
            assert_match %r{/images/ext/#{klass}.png}, img_tag(subject)
          end

          should 'use mode on static asset' do
            assert_match %r{/images/ext/#{klass}_pv.png}, img_tag(subject, :mode => 'pv')
          end

          should 'set class to node' do
            assert_match 'img.node', img_tag(subject)
          end
        end # on img_tag
      end # with a ...
    end # each

    context 'on any node' do
      setup do
        visiting(:status)
      end

      context 'receiving flash_messages' do
        should 'wrap flash messages in div' do
          assert_match 'div#messages', flash_messages(:show => 'both')
        end

        should 'not show notice or error divs' do
          assert_no_match %r{error|notice}, flash_messages(:show => 'both')
        end

        context 'with a notice' do
          setup do
            flash[:notice] = 'Amy & Eve'
          end

          should 'wrap notices in div' do
            assert_match 'div#messages div#notice', flash_messages(:show => 'both')
          end

          should 'show notice' do
            assert_match %r{Amy & Eve}, flash_messages(:show => 'both')
          end
        end

        context 'with an error' do
          setup do
            flash[:error] = 'war'
          end

          should 'wrap errors in div' do
            assert_match 'div#messages div#error', flash_messages(:show => 'both')
          end

          should 'show error' do
            assert_match %r{war}, flash_messages(:show => 'both')
          end
        end
      end # receiving flash_messages
    end # on any node

    context 'displaying readers list' do
      context 'with a public node' do
        subject do
          nodes(:status)
        end

        should 'display public group image' do
          assert_match %r{/images/user_pub.png}, readers_for(subject)
        end
      end # with a public node

      context 'with a non published node' do
        subject do
          secure(Node) { Page.new(:parent_id => nodes_id(:zena), :title => 'new node')}
        end

        should 'not display public image' do
          assert_no_match %r{/images/user_pub.png}, readers_for(subject)
        end

        should 'display public group name' do
          assert_no_match %r{public}, readers_for(subject)
        end
      end # with a non published node


      context 'with a node with custom rights' do
        subject do
          nodes(:secret)
        end

        should 'display cog sign' do
          assert_match %r{/images/cog.png}, readers_for(subject)
        end
      end # with a node with custom rights

      context 'with a non public node' do
        subject do
          nodes(:strange)
        end

        should 'show read group name' do
          assert_match %r{admin}, readers_for(subject)
        end

        should 'show write group name' do
          assert_match %r{managers}, readers_for(subject)
        end

        should 'not show drive group name' do
          assert_no_match %r{workers}, readers_for(subject)
        end
      end # with a non public node
    end # displaying readers list
  end # A logged in user

  def test_img_tag_other
    login(:tiger)
    doc = secure!(Node) { nodes(:water_pdf) }
    doc.ext = 'bin'
    assert_equal 'bin', doc.ext
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' alt='bin document' class='doc'/>", img_tag(doc)
    assert_equal "<img src='/images/ext/other_pv.png' width='70' height='70' alt='bin document' class='doc'/>", img_tag(doc, :mode=>'pv')
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' alt='bin document' class='doc'/>", img_tag(doc, :mode=>'std')
  end

  def test_alt_with_apos
    doc = secure!(Node) { nodes(:lake_jpg) }
    assert_equal "<img src='/en/projects/cleanWater/image24.jpg?1144713600' width='600' height='440' alt='it&apos;s a lake' class='full'/>", img_tag(doc)
  end

  def test_select_id
    login(:ant)
    @node = secure!(Node) { nodes(:status) }
    select = select_id('node', :parent_id, :class => 'Project')
    assert_no_match %r{select.*node\[parent_id\].*21.*19.*29.*11}m, select
    #assert_match %r{select.*node\[parent_id\].*29}m, select
    # no more select
    assert_match %r{input.*node\[parent_id\].*21}m, select
    login(:tiger)
    @node = secure!(Node) { nodes(:status) }
    # no more select
    #assert_match %r{select.*node\[parent_id\].*21.*19.*29.*11}m, select_id('node', :parent_id, :class=>'Project')
    assert_match %r{input.*node\[parent_id\].*21}m, select_id('node', :parent_id, :class=>'Project')
    assert_match %r{input type='text'.*name.*node\[icon_id\]}m, select_id('node', :icon_id)
  end

  # No more select
  # def test_select_id_with_empty_value
  #   login(:lion)
  #   vclass = VirtualClass.create(:superclass => 'Post', :name => 'Foo', :create_group_id =>  groups_id(:public))
  #   @node = secure!(Node) { nodes(:status) }
  #   select = select_id('node', :parent_id, :class=>'Foo')
  #   assert_match %r{<select[^>]*></select>}, select
  # end

  def test_show_path_root
    login(:anon)
    @node = secure!(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<li><a href='/en' class='current'>Zena the wild CMS</a></li>", show_path
    @node = secure!(Node) { Node.find(nodes_id(:status))}
    assert_match %r{.*Zena.*projects.*Clean Water.*li.*page22\.html' class='current'>status}m, show_path
  end

  def test_show_path_root_with_login
    login(:ant)
    @node = secure!(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<li><a href='/#{AUTHENTICATED_PREFIX}' class='current'>Zena the wild CMS</a></li>", show_path
  end

  def map_actions(version)
    version_actions(version, :actions => :all
    ).split(%r{<.*/nodes/#{version.node.zip}/versions/#{version.number}/}).map{|l| l.gsub(/\?.*/,'').strip
    }.reject {|l| l.blank? }.sort
  end

  def test_version_actions
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal %w{ unpublish }, map_actions(node.version)
    node.update_attributes('title' => 'meia lua de compasso')
    node = secure!(Node) { nodes(:status) }
    assert_equal %w{ propose publish remove }, map_actions(node.version)
    node.propose
    assert_equal %w{ publish refuse }, map_actions(node.version)
  end

  def test_version_action_view
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_match %r{Zena.version_preview\('/nodes/#{node.zip}/versions/#{node.version.number}'\)}, version_actions(node.version, :actions => :view)
  end

  def test_popup_images
    login(:anon)
    img = secure!(Node) { nodes(:bird_jpg) }
    @controller.instance_variable_set(:@js_data, nil)
    img_tag(img)
    assert_equal [], @controller.js_data
    img_tag(img, :mode => 'med', :id => 'flop') # med has a popup setting
    popup_data = JSON.load(@controller.js_data[0][%r{\A.*?(\{.*\}).*\Z},1])
    assert_equal '/en/image30_std.jpg?929831698949', popup_data['src']
    assert_equal 400, popup_data['height']
    assert_equal 440, popup_data['width']
  end
end