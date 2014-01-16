require 'test_helper'

class RenderingTest < Zena::View::TestCase
  context 'With a node and skin' do
    setup do
      login(:anon)
      visiting(:status)
    end

    context 'resolving template_url' do

      should 'append host and insert lang on template_path_from_template_url' do
        assert_equal '/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID.erb', template_path_from_template_url('', 'SKIN/TEMPLATE/DOM_ID', false)
      end
      
      should 'build template on template_path_from_template_url' do
        fullpath = fullpath_from_template_url('wiki skin/Page-changes/_main', false)
        if File.exist?(fullpath)
          FileUtils.rm(fullpath)
        end
        assert_equal '/test.host/zafu/wiki skin/Page-changes/en/foo.erb', template_path_from_template_url('', 'wiki skin/Page-changes/foo', true)
        assert File.exist?(fullpath)
        FileUtils.rm(fullpath)
      end
      
      should 'build template partial on template_path_from_template_url' do
        fullpath  = fullpath_from_template_url('Default skin/Node/pages', false)
        main_path = fullpath_from_template_url('Default skin/Node/_main', false)
        FileUtils.rm(fullpath)  if File.exist?(fullpath)
        FileUtils.rm(main_path) if File.exist?(main_path)
        assert_equal '/test.host/zafu/Default skin/Node/en/pages.erb', template_path_from_template_url('', 'Default skin/Node/pages', true)
        assert File.exist?(main_path)
        assert File.exist?(fullpath)
        FileUtils.rm(fullpath)
      end
      
      context 'with an alias site' do
        setup do
          setup_visitor(visitor, Site.find_by_host('alias.host'))
        end
        
        should 'build template on template_path_from_template_url' do
          fullpath = fullpath_from_template_url('wiki skin/Page-changes/_main', false)
          if File.exist?(fullpath)
            FileUtils.rm(fullpath)
          end
          assert_equal '/test.host/zafu/wiki skin/Page-changes/en/foo.erb', template_path_from_template_url('', 'wiki skin/Page-changes/foo', true)
          assert File.exist?(fullpath)
          FileUtils.rm(fullpath)
        end

        should 'build template partial on template_path_from_template_url' do
          fullpath  = fullpath_from_template_url('Default skin/Node/pages', false)
          main_path = fullpath_from_template_url('Default skin/Node/_main', false)
          FileUtils.rm(fullpath)  if File.exist?(fullpath)
          FileUtils.rm(main_path) if File.exist?(main_path)
          assert_equal '/test.host/zafu/Default skin/Node/en/pages.erb', template_path_from_template_url('', 'Default skin/Node/pages', true)
          assert File.exist?(main_path)
          assert File.exist?(fullpath)
          FileUtils.rm(fullpath)
        end
        
        should 'find site alias on visitor site' do
          assert_equal 'alias.host', visitor.site.host
        end
        
        should 'find forced skin on any node' do
          assert_equal 'wiki skin', visitor.get_skin(nodes(:zena)).title
        end
      end
      
      should 'return a fullpath on fullpath_from_template_url' do
        assert_equal "#{SITES_ROOT}/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID.erb", fullpath_from_template_url('SKIN/TEMPLATE/DOM_ID', false)
      end

      should 'return a relative path on admin_layout' do
        assert_equal "/test.host/zafu/Default skin/Node-+adminLayout/en/_main.erb", controller.admin_layout
      end
    end # Rendering

    context 'compiling a template' do
      should 'end with render_js inclusion' do
        assert_match %r{<%= render_js %></body>}, File.read(File.join(SITES_ROOT, controller.template_url))
      end
    end # compiling a template
  end # With a node and skin
end

class RenderingControllerTest < Zena::Controller::TestCase
  tests NodesController

  class MockSession < ActiveRecord::Base
    set_table_name :sessions
    before_save :set_session_id
    def set_session_id
      self[:session_id] = UUIDTools::UUID.random_create.to_s
    end
  end

  def make_template(zafu, mode = 'special')
    login(:lion)
    # create template for 'special' mode
    @template = secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => "Node-#{mode}.zafu", :text => zafu, :v_status => Zena::Status::Pub) }
  end

  context 'A custom rendering engine' do
    setup do
      login(:anon)
      self.session.session_id = MockSession.create.session_id
      class << @controller
        attr_reader :custom_rendering
        def render_to_xml(opts)
          @custom_rendering = opts
          {
            :type => 'text/html',
            :data => render_to_string(:inline => %Q{<%= zazen(%q{Hello !30! "a link":30}) %>}),
          }
        end
      end
    end

    subject do
      {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}.xml"], :prefix => 'en'}
    end

    should 'call render_to_format' do
      get_subject
      assert !@controller.custom_rendering[:debug]
      assert_equal 'xml', @controller.custom_rendering[:format]
    end

    context 'with debug' do
      subject do
        {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}.xml"], :prefix => 'en', :debug => 'true'}
      end

      should 'pass debug to render_to_format on debug' do
        get_subject
        assert @controller.custom_rendering[:debug]
      end
    end # with debug

  end # A custom rendering engine

  context 'Custom headers' do
    subject do
      login(:lion)
      # create template for 'special' mode
      t = secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node--csv.zafu', :text => @zafu, :v_status => Zena::Status::Pub) }
      login(:anon)
      {:action => 'show', :controller => 'nodes', :path => ["section#{nodes_zip(:people)}.csv"], :prefix => 'en'}
    end

    should 'set type and disposition headers' do
      @zafu = %q{<r:headers X-Foobar='my thing' Content-Type='text/css' Content-Disposition='attachment; filename=special_#{title}.csv'/>}
      get_subject
      assert_response :success
      {
        "X-Foobar"            => "my thing",
        "Content-Type"        => "text/css; charset=utf-8",
        "Content-Disposition" => "attachment; filename=special_people.csv",
      }.each do |k, v|
        assert_equal v, @response.headers[k]
      end
    end
  end # Custom headers

  context 'special rendering zafu' do
    subject do
      {:action => 'show', :controller => 'nodes', :path => ["section#{nodes_zip(:people)}_#{@mode}.html"], :prefix => 'en'}
    end

    context 'to raise not found' do
      setup do
        @mode = 'nf'
        make_template "<r:not_found/>", @mode
        login(:anon)
      end

      should 'raise not found' do
        # Stupid tests. Raises ActionView::TemplateError during testing and
        # ActiveRecord::RecordNotFound in production.
        assert_raise(ActionView::TemplateError) { get_subject }
      end # Not found rendering
    end # to raise not found

    # Not working yet...
    # context 'to redirect' do
    #   setup do
    #     @mode = 'redir'
    #     make_template "<r:redirect url='http://feature-space.com'/>", @mode
    #     login(:anon)
    #   end
    #
    #   should 'redirect' do
    #     get_subject
    #     assert_redirected_to 'http://feature-space.com'
    #   end
    # end # to redirect

    context 'to update' do
      setup do
        @mode = 'ins'
        make_template "<div id='foo' do='block'>hello <r:title/></div>", @mode
        login(:anon)
        # render page to build template
        get 'show', :path => ["section#{nodes_zip(:people)}_#{@mode}.html"], :prefix => 'en'
        assert_equal "<div id='foo' data-z='12'>hello people</div>", @response.body
      end

      should 'execute Element update' do
        get 'zafu', {
          :id     => nodes_zip(:people),
          :t_url  => 'Default skin/Node-ins/foo',
          :dom_id => 'foo',
        }
        assert_equal %Q{if (Zena.stampOk('foo', 0)) {\nElement.replace(\"foo\", \"\\u003Cdiv id='foo' data-z='12'\\u003Ehello people\\u003C/div\\u003E\");\n\n}}, @response.body
      end

      context 'with insert' do
        should 'execute Zena insert_inner' do
          get 'zafu', {
            :id     => nodes_zip(:people),
            :t_url  => 'Default skin/Node-ins/foo',
            :dom_id => 'foo',
            :insert => 'bottom',
          }
          assert_equal %Q{if (Zena.stampOk('foo', 0)) {\nZena.insert_inner(\"foo\", \"bottom\", \"\\u003Cdiv id='foo' data-z='12'\\u003Ehello people\\u003C/div\\u003E\");\n\n}}, @response.body
        end
      end # with insert
    end # to update
  end # special rendering zafu

  context 'Custom headers on html' do
    setup do
      make_template %q{<r:headers X-Foobar='my thing' Content-Type='text/css' Content-Disposition='attachment; filename=special_#{title}.csv'/>}, 'bar'
    end
    
    subject do
      login(:anon)
      {:action => 'show', :controller => 'nodes', :path => ["section#{nodes_zip(:people)}_bar.html"], :prefix => 'en'}
    end

    should 'set type and disposition headers' do
      get_subject
      assert_response :success
      {
        "X-Foobar"            => "my thing",
        "Content-Type"        => "text/css; charset=utf-8",
        "Content-Disposition" => "attachment; filename=special_people.csv",
      }.each do |k, v|
        assert_equal v, @response.headers[k]
      end
    end
  end
  
  context 'With a master template' do
    setup do
      make_template %q{MASTER_TEMPLATE[<r:master_template do='id'/>]}, 'baz'
    end
    
    subject do
      login(:anon)
      {:action => 'show', :controller => 'nodes', :path => ["section#{nodes_zip(:people)}_baz.html"], :prefix => 'en'}
    end
    
    should 'find master template' do
      get_subject
      assert_response :success
      assert_equal "MASTER_TEMPLATE[#{@template.zip}]", @response.body
    end
  end # Custom headers on html

end