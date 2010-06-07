require 'test_helper'

class ZafuTemplateTest < Zena::View::TestCase

  context 'Without a logged in user' do
    setup do
      login(:anon)
      visiting(:status)
    end

    should 'receive page_numbers' do
      s = ""
      page_numbers(2, 3, ',') {|p,j| s << "#{j}#{p}"}
      assert_equal "1,2,3", s
      s = ""
      page_numbers(2, 30, ',') {|p,j| s << "#{j}#{p}"}
      assert_equal "1,2,3,4,5,6,7,8,9,10", s
      s = ""
      page_numbers(14, 30, ',') {|p,j| s << "#{j}#{p}"}
      assert_equal "10,11,12,13,14,15,16,17,18,19", s
      s = ""
      page_numbers(28, 30, ' | ') {|p,j| s << "#{j}#{p}"}
      assert_equal "21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30", s
    end
  end # Without a logged in user

  context 'Rendering a template' do
    setup do
      login(:anon)
      visiting(:status)
    end

    should 'find best template based on class' do
      assert_match %r{default/Node}, @controller.send(:template_url)
    end

    context 'with an admin visitor' do
      setup do
        login(:lion)
      end

      should 'use visitor chosen dev skin' do
        visitor.dev_skin_id = nodes_zip(:wikiSkin)
        assert_match %r{/wikiSkin/Node}, @controller.send(:template_url)
      end

      should 'use rescue skin' do
        visitor.dev_skin_id = User::RESCUE_SKIN_ID
        assert_match %r{/\$default/Node}, @controller.send(:template_url)
      end

      should 'use any skin' do
        visitor.dev_skin_id = User::ANY_SKIN_ID
        assert_match %r{/default/Node}, @controller.send(:template_url)
        visiting(:wiki)
        assert_match %r{/wikiSkin/Node}, @controller.send(:template_url)
      end

      should 'not insert dev_box for non html content' do
        # TODO
        print 'P'
      end
    end # with an admin visitor

    context 'without an admin visitor' do
      setup do
        login(:anon)
      end

      should 'not include dev box' do
        session[:dev] = true
        assert !dev_mode?
      end

      should 'not use visitor skin mode' do
        visitor.dev_skin_id = nodes_zip(:wikiSkin)
        assert_match %r{/default/Node}, @controller.send(:template_url)
      end
    end # without an admin visitor
    #def test_template_url_virtual_class
    #  without_files('zafu') do
    #    node = @controller.send(:secure,Node) { nodes(:opening) }
    #    # FIXME: finish to test virtual class template_url (create fixture)
    #    @controller.instance_variable_set(:@node, node)
    #    assert_equal '.....', @controller.send(:template_url)
    #    assert File.exist?(File.join(Zena::ROOT, '.....')), "File exist"
    #  end
    #end
    #
    #def test_template_url_any
    #  without_files('app/views/templates/compiled') do
    #    bird = @controller.send(:secure,Node) { Node.find(nodes_id(:bird_jpg)) }
    #    assert_equal 'wiki', bird.skin
    #    @controller.instance_variable_set(:@node, bird)
    #    assert !File.exist?(File.join(Zena::ROOT, 'app/views/templates/compiled/wiki/any_en.rhtml')), "File does not exist"
    #    assert_equal '/templates/compiled/wiki/any_en', @controller.send(:template_url)
    #    assert File.exist?(File.join(Zena::ROOT, 'app/views/templates/compiled/wiki/any_en.rhtml')), "File exist"
    #  end
    #end
    #
    #def test_template_url_index
    #  bird = @controller.send(:secure,Node) { Node.find(nodes_id(:bird_jpg)) }
    #  assert_equal 'wiki', bird.skin
    #  @controller.instance_variable_set(:@node, bird)
    #  assert_equal '/templates/fixed/default/any__index', @controller.send(:template_url, :mode=>'index')
    #end
  end # Rendering a template

  context 'Rendering a default template' do
    setup do
      login(:anon)
      visiting(:status)
    end

    context 'on default_template_url' do
      should 'return a template with pseudo skin $default' do
        assert_match %r{\$default/Node}, default_template_url
      end

      should 'return index on index mode' do
        assert_match %r{\$default/Node-\+index}, default_template_url(:mode => '+index')
      end

      should 'raise not found on none html format' do
        assert_raise(ActiveRecord::RecordNotFound) { default_template_url(:format => 'xml') }
      end
    end # on default_template_url

    context 'on get_template_text' do
      should 'read content from filesystem' do
        assert_equal "<r:include template='$default/Node'/>", get_template_text('$default/Node-+index', 'foo').first
      end
    end # on get_template_text
  end # Rendering a default template
end