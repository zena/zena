require 'tempfile'

module Zena
  module Use
    module Rendering
      class Redirect < Exception
        attr_reader :url

        def initialize(url)
          @url = url
        end
      end # Redirect class

      module ViewMethods
        # Append javascript to the end of the page.
        def render_js(in_html = true)
          return '' unless js_data
          js = js_data.join("\n")
          if in_html
            javascript_tag(js)
          else
            js
          end
        end

        def set_headers(params)
          zafu_headers.merge!(params)
        end

        def help(key)
          %Q{<div class='help'><p>#{key}</p></div>}
        end
      end

      module ControllerMethods
        def self.included(base)
          base.send(:helper_attr, :js_data, :zafu_headers)
          base.send(:layout, false)
        end

        def js_data
          @js_data ||= []
        end

        def zafu_headers
          @zafu_headers ||= {}
        end

        # TODO: test
        # Our own handling of exceptions
        def rescue_action_in_public(exception)
          case exception
          when ActiveRecord::RecordNotFound, ActionController::UnknownAction
            render_404(exception)
          else
            render_500(exception)
          end
        end

        def rescue_action(exception)
          case exception
          when ActiveRecord::RecordNotFound, ActionController::UnknownAction
            render_404(exception)
          else
            super
          end
        end

        # TODO: test
        def render_404(exception)
          if Thread.current[:visitor]
            # page not found
            @node = current_site.root_node
            zafu_node('@node', Project)

            respond_to do |format|
              format.xml  { render :nothing => true, :status => "404 Not Found" }
              format.all do
                not_found = "#{SITES_ROOT}/#{current_site.host}/public/#{prefix}/404.html"
                if File.exists?(not_found)
                  render :text => File.read(not_found), :status => '404 Not Found'
                else
                  render_and_cache :mode => '+notFound', :format => 'html', :cache_url => "/#{prefix}/404.html", :status => '404 Not Found'
                end
              end
            end
          else
            # site not found
            respond_to do |format|
              format.html { render :text    => File.read("#{Zena::ROOT}/app/views/sites/404.html"), :status => '404 Not Found' }
              format.all  { render :nothing => true, :status => "404 Not Found" }
            end
          end
        rescue ActiveRecord::RecordNotFound => err
          # this is bad
          render_500(err)
        end

        # TODO: test
        def render_500(exception)
          # TODO: send an email with the exception ?

        #       msg =<<-END_MSG
        # Something bad happened to your zena installation:
        # --------------------------
        # #{exception.message}
        # --------------------------
        # #{exception.backtrace.join("\n")}
        # END_MSG

          respond_to do |format|
            format.html { render :text    => File.read("#{Zena::ROOT}/app/views/nodes/500.html"), :status => '500 Error' }
            format.all  { render :nothing => true, :status => "500 Error" }
          end
        end

        def render_and_cache(options={})
          # FIXME: maybe we can remove this.
          @title_for_layout = title_for_layout

          opts = {:skin => @node[:skin], :cache => true}.merge(options)
          opts[:mode  ] ||= params[:mode]
          opts[:format] ||= params[:format].blank? ? 'html' : params[:format]
          #
          # cleanup before rendering
          params.delete(:mode)
          if opts[:format] != 'html'

            method = "render_to_#{opts[:format]}"
            if params.keys.include?('debug')
              opts[:cache] = false
              opts[:debug] = true
            end

            if respond_to?(method)
              # Call custom rendering engine 'render_to_pdf' for example.
              result = send(method, opts)
            else
              template_path = template_url(opts)
              # FIXME: Use Mime types to resolve content type...
              content_type  = (Zena::EXT_TO_TYPE[opts[:format]] || ['application/octet-stream'])[0]
              result = {
                :data         => render_to_string(:file => template_path, :layout=>false),
                :disposition  => 'inline',
                :type         => content_type,
                :filename     => @node.title
              }
            end

            if error = result[:error]
              # error reporting from rendering engine
              opts[:cache] = false
              @render_error = error
              render :file => 'nodes/render_error'
            else
              if zafu_headers
                if disposition = zafu_headers.delete('Content-Disposition')
                  result.delete(:filename) if disposition =~ /filename\s*=/
                  result[:disposition] = disposition
                end

                if type = zafu_headers.delete('Content-Type')
                  result[:type] = type
                end

                if filename = zafu_headers.delete('filename')
                  result[:filename] = filename
                end

                headers.merge!(zafu_headers)
              end

              if data = result.delete(:data)
                send_data(data , result)
              elsif file = result.delete(:file)
                send_file(file , result)
              else
                # Should never happen
                raise Exception.new("Render '#{params[:format]}' should return either :file or :data (none found).")
              end
            end

            cache_page(:content_data => result[:data], :content_path => result[:file]) if opts[:cache]
          else
            # html
            render :file => template_url(opts), :layout=>false, :status => opts[:status]
            headers.merge!(zafu_headers)
            cache_page(:url => opts[:cache_url]) if opts[:cache]
          end
        # This does not work, Rendering::Redirect is wrapped in TemplateError
        # rescue Zena::Use::Rendering::Redirect
        # This does not work either: infinity loop, CPU hog on errors.
        # rescue ActionView::TemplateError => err
        #   orig = err.original_exception
        #   if orig.kind_of?(Zena::Use::Rendering::Redirect)
        #     redirect_to orig.url
        #   else
        #     raise err
        #   end
        rescue ActiveRecord::RecordNotFound => err
          return render_404(err)
        end

        # Cache page content into a static file in the current sites directory : SITES_ROOT/test.host/public
        def cache_page(opts={})
          if cachestamp_format?(params['format'])
            headers['Expires'] = (Time.now + 365*24*3600).strftime("%a, %d %b %Y %H:%M:%S GMT")
            headers['Cache-Control'] = (!current_site.authentication? && @node.public?) ? 'public' : 'private'
          end

          if perform_caching && caching_allowed(:authenticated => opts.delete(:authenticated))
          
            url = page_cache_file(opts.delete(:url))
            opts = {:expire_after  => nil,
                    :path          => (current_site.public_path + url),
                    :content_data  => response.body,
                    :node_id       => @node[:id]
                    }.merge(opts)
            secure!(CachedPage) { CachedPage.create(opts) }
          end
        end

        # Return true if we can cache the current page
        def caching_allowed(opts = {})
          return false if current_site.authentication? || query_params != {}
          # Cache even if authenticated (public content).
          #                       Content viewed by anonymous user should be cached anyway.
          opts[:authenticated] || visitor.is_anon?
        end

        # Cache file path that reflects the called url
        def page_cache_file(url = nil)
          path = url || url_for(:only_path => true, :skip_relative_url_root => true, :cachestamp => nil)
          path = ((path.empty? || path == "/") ? "/index" : URI.unescape(path))
          ext = params[:format].blank? ? 'html' : params[:format]
          path << ".#{ext}" unless path =~ /\.#{ext}(\?\d+|)$/
          #
          # FULL QUERY_STRING in cached page ?
          if cachestamp_format?(params['format'])
            # We have to use a '.' because apache cannot serve static files with '?'.
            path << "." << make_cachestamp(@node, params['mode'])
          end
          path
        end

        # Find the proper layout to render 'admin' actions. The layout is searched into the visitor's contact's skin first
        # and then into default. This action is also responsible for setting a default @title_for_layout.
        def admin_layout
          @title_for_layout ||= "#{params[:controller]}/#{params[:action]}"
          template_url(:mode => '+adminLayout')
        end

        # TODO: test
        def popup_layout
          js_data << "var is_editor = true;"
          template_url(:mode=>'+popupLayout')
        end

        # Return the window title to use.
        def title_for_layout
          return '' unless @node
          @node.title + (@node.kind_of?(Document) ? ".#{@node.ext}" : '')
        end

        # Use the current visitor as master node.
        def visitor_node
          @node = visitor.node
          zafu_node('@node', Node)
        end

        private
          # This is called before rendering for special formats (pdf) in order to rewrite
          # urls to localhost (the rendering engine is external to Zena and will need to
          # make calls to get assets).
          def baseurl
            if Zena::ASSET_PORT > 0
              if Zena::ASSET_PORT == request.port
                raise Exception.new("Custom rendering not allowed on this process (port == asset_port).")
              else
                "http://127.0.0.1:#{Zena::ASSET_PORT}"
              end
            else
              # This can break if using mongrel and round-robin (deadlock)
              "#{ssl_request? ? 'https' : 'http'}://#{current_site.host}"
            end
          end

          def get_render_auth_params
            {
              :http_user     => visitor.id,
              :http_password => visitor.persistence_token,
              :baseurl       => baseurl
            }
          end
      end # ControllerMethods

      module ZafuMethods
        def r_headers
          headers = []
          @params.each do |k, v|
            headers << "#{k.to_s.inspect} => #{RubyLess.translate_string(self, v)}"
          end
          if headers.empty?
            out ""
          else
            out "<% set_headers(#{headers.join(', ')}) %>"
          end
        end

        def r_style
          @markup.tag = 'style'
          @markup.set_param(:type, 'text/css')
          expand_with
        end

        def r_not_found
          out "<% raise ActiveRecord::RecordNotFound %>"
        end

        # Does not work properly. FIXME.
        # def r_redirect
        #   out parser_error('Missing "url" parameter.') unless url = @params[:url]
        #   code = ::RubyLess.translate_string(self, url)
        #   out "<% raise Zena::Use::Rendering::Redirect.new(#{code}) %>"
        # end
      end # ZafuMethods
    end # Rendering
  end # Use
end # Zena
