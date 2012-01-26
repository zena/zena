ActionController::Routing::Routes.add_route '----/test/:action', :controller => 'zena/test'

module Zena
  class TestController < ApplicationController
    include Zena::Use::Fixtures
    include Zena::Use::TestHelper
    helper_method :get_template_text, :template_url_for_asset, :save_erb_to_url
    skip_before_filter :set_visitor
    prepend_before_filter :set_context

    include  Zena::Use::HtmlTags::ViewMethods

    class << self
      def templates=(templates)
        @@templates = templates
      end
    end

    def rescue_action_in_public(err)
      render :text => ([err.message] + err.backtrace[0..4]).join("    \n")
    end

    def rescue_action(err)
      render :text => ([err.message] + err.backtrace[0..4]).join("    \n")
    end

    # Get render_js content from template
    def render_js
      @template.send(:render_js)
    end

    def test_compile

      klass = VirtualClass[params.delete(:class) || 'Node']

      render :text => Zena::ZafuCompiler.new_with_url(@test_url, :helper => zafu_helper).to_erb(:dev => params['dev'], :node => Zena::Use::NodeContext.new('@node', klass))
    rescue => err
      render :text => ([err.message] + err.backtrace[0..4]).join("    \n").tap {|x| puts x}
    end

    def test_render
      if params[:format] then
        met = :"render_to_#{params[:format]}"
        if respond_to?(met)
          result = self.send(met, {:inline => @text})
          render :text => result[:data]
          headers.merge!(result[:type])
          return
        else
        end
      else
        render :text => "Cannot handle #{params[:format]} rendering."
      end
    rescue => err
      render :text => ([err.message] + err.backtrace[0..4]).join("    \n")
    end

    def test_zazen
      render :text => ZazenParser.new(@text, :helper => zafu_helper).render
    end

    private
    # by pass application before actions
    def authorize
    end

    def set_lang
    end

    # We skip authlogic
    def set_context
      login(params[:user])
      set_visitor_lang(params[:prefix])
      @node = secure!(Node) { Node.find(params[:node_id])}
      @text = params[:text]
      @test_url  = params[:url]
      params.delete(:user_id)
      params.delete(:user)
      params.delete(:prefix)
      params.delete(:node_id)
      params.delete(:text)
      params.delete(:url)

      if controller = params.delete(:fake_controller)
        # This is used when we need url rewriting.
        case controller
        when 'nodes'
          self.request = ActionController::TestRequest.new

          self.request.tap do |request|
            request.path_parameters = {
              'controller' => 'nodes',
              'action'     => 'show',
              'path'       => zen_path(@node).split('/')[2..-1],
              'prefix'     => visitor.is_anon? ? visitor.lang : AUTHENTICATED_PREFIX,
            }
            request.symbolized_path_parameters
            self.params = request.params
            initialize_current_url
          end

        end
      end
    end

    def get_template_text(path, base_path)
      folder = base_path.blank? ? [] : base_path[1..-1].split('/')
      if path[0..0] == '/'
        # just ignore the 'relative' or 'absolute' tricks.
        test_path = path[1..-1]
      else
        test_path = path
      end
      url = (folder + test_path.split('/')[1..-1]).join('_')

      if test = @@templates[url]
        [test['src'], test_path]
      else
        # 'normal' include
        @expire_with_nodes = {}
        @skin_names = ['default']
        super
      end
    end

  end
end