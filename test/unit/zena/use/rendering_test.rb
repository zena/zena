require 'test_helper'

class RenderingTest < Zena::View::TestCase
  context 'With a node and skin' do
    setup do
      login(:anon)
      visiting(:status)
    end

    context 'resolving template_url' do

      should 'append host and insert lang on template_path_from_template_url' do
        assert_equal '/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID', template_path_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a fullpath on fullpath_from_template_url' do
        assert_equal "#{SITES_ROOT}/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID", fullpath_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a relative path on admin_layout' do
        assert_equal "/test.host/zafu/Default skin/Node-%2BadminLayout/en/_main.erb", controller.admin_layout
      end
    end # Rendering

    context 'compiling a template' do
      should 'end with render_js inclusion' do
        assert_match %r{<%= render_js %></body>}, File.read(File.join(SITES_ROOT, controller.template_url))
      end
    end # compiling a template
  end # With a node and skin
end

class RenderingInControllerTest < Zena::Controller::TestCase
  tests NodesController

  class MockSession < ActiveRecord::Base
    set_table_name :sessions
    before_save :set_session_id
    def set_session_id
      self[:session_id] = UUIDTools::UUID.random_create.to_s
    end
  end

  context 'A custom rendering engine' do
    setup do
      login(:anon)
      self.session.session_id = MockSession.create.session_id
      class << @controller
        attr_reader :custom_rendering
        def render_to_xml(opts)
          @custom_rendering = true
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
      assert @controller.custom_rendering
    end

    context 'with debug' do
      subject do
        {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}.xml"], :prefix => 'en', :debug => 'true'}
      end

      should 'not call render_to_format on debug' do
        get_subject
        assert_nil @controller.custom_rendering
      end
    end # with debug

  end # A custom rendering engine

  context 'Custom rendering options' do
    subject do
      login(:lion)
      # create template for 'special' mode
      t = secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node--csv.zafu', :text => @zafu, :v_status => Zena::Status[:pub]) }
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
  end # Custom rendering options

  context 'Custom rendering options on html' do
    subject do
      login(:lion)
      # create template for 'special' mode
      t = secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node-bar.zafu', :text => @zafu, :v_status => Zena::Status[:pub]) }
      login(:anon)
      {:action => 'show', :controller => 'nodes', :path => ["section#{nodes_zip(:people)}_bar.html"], :prefix => 'en'}
    end

    should 'type and disposition headers' do
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
  end # Custom rendering options

end