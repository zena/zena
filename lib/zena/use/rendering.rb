require 'tempfile'

module Zena
  module Use
    module Rendering
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
      end

      module ControllerMethods
        def self.included(base)
          base.send(:helper_attr, :js_data)
          base.send(:layout, false)
        end

        def js_data
          @js_data ||= []
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
              format.html do
                not_found = "#{SITES_ROOT}/#{current_site.host}/public/#{prefix}/404.html"
                if File.exists?(not_found)
                  render :text => File.read(not_found), :status => '404 Not Found'
                else
                  render_and_cache :mode => '+notFound', :format => 'html', :cache_url => "/#{prefix}/404.html", :status => '404 Not Found'
                end
              end
              format.all  { render :nothing => true, :status => "404 Not Found" }
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
          opts = {:skin=>@node[:skin], :cache=>true}.merge(options)
          opts[:mode  ] ||= params[:mode]
          opts[:format] ||= params[:format].blank? ? 'html' : params[:format]
          # cleanup before rendering
          params.delete(:mode)
          if opts[:format] != 'html'
            # Document data or special renderings.
            content_type  = (Zena::EXT_TO_TYPE[opts[:format]] || ['application/octet-stream'])[0]
            template_path = template_url(opts)
            data = render_to_string(:file => template_path, :layout=>false)
            # TODO: use plugins...
            #if opts[:format] == 'pdf' && ((Zena::ENABLE_LATEX && data =~ /\A% (latex)\n/) || (Zena::ENABLE_FOP && data =~ /\A<\?(xml)/))
             # render_pdf($1 == 'xml' ? 'fop' : $1)

            if opts[:format] == 'pdf'
              Data2pdf.engine =  'Xhtml2pdf'
              disposition = params['disposition']   || 'inline'
              if params.keys.include?("debug")
                render :text => data
              else
                pdf = Data2pdf.render(data)
                send_data(pdf,  :type=> 'application/pdf', :disposition=>disposition)
              end
            else
              # send data inline
              filepath = nil
              send_data( data , :filename=>@node.title, :type => content_type, :disposition=>'inline')
            end

            cache_page(:content_data => data, :content_path => filepath) if opts[:cache]
          else
            # html
            render :file => template_url(opts), :layout=>false, :status => opts[:status]
            cache_page(:url => opts[:cache_url]) if opts[:cache]
          end
        end

        # Cache page content into a static file in the current sites directory : SITES_ROOT/test.host/public
        def cache_page(opts={})
          return unless perform_caching && caching_allowed(:authenticated => opts.delete(:authenticated))
          url = page_cache_file(opts.delete(:url))
          opts = {:expire_after  => nil,
                  :path          => (current_site.public_path + url),
                  :content_data  => response.body,
                  :node_id       => @node[:id]
                  }.merge(opts)
          secure!(CachedPage) { CachedPage.create(opts) }
          if cachestamp_format?(params['format'])
            headers['Expires'] = (Time.now + 365*24*3600).strftime("%a, %d %b %Y %H:%M:%S GMT")
            headers['Cache-Control'] = 'public'
          end
        end

        # Return true if we can cache the current page
        def caching_allowed(opts = {})
          return false if current_site.authentication? || query_params != {}
          opts[:authenticated] || visitor.is_anon?
        end

        # Cache file path that reflects the called url
        def page_cache_file(url = nil)
          path = url || url_for(:only_path => true, :skip_relative_url_root => true, :cachestamp => nil)
          path = ((path.empty? || path == "/") ? "/index" : URI.unescape(path))
          ext = params[:format].blank? ? 'html' : params[:format]
          path << ".#{ext}" unless path =~ /\.#{ext}(\?\d+|)$/
          # Do not cache filename with query or apache will not see it !
          # if cachestamp_format?(params['format'])
          #   path << "?" << make_cachestamp(@node, params['mode'])
          # end
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

        # Use the current visitor as master node.
        def visitor_node
          @node = visitor.contact
          zafu_node('@node', BaseContact)
        end

        def render_pdf(rendering_egine)
          # 1. find cached PDF. If found, send data.
          if @node[:user_id] == visitor[:id]
            # owner
            filename = "u#{@node[:user_id]}.pdf"
          else
            # group
            filename = "g#{@node[:rgroup_id]}.pdf"
          end
          filepath = @node.asset_path(filename)
          if File.exist?(filepath)
            # ok send data
            data = File.read(filepath)
            send_data( data , :filename=>@node.title, :type => content_type, :disposition=>'inline')
          else
            # generate pdf
            FileUtils::mkpath(File.dirname(filepath)) unless File.exist?(File.dirname(filepath))

            tempf = Tempfile.new("#{@node[:id]}_#{@node.version.lang}")
            pdf_path = "#{tempf.path}.pdf"
            failure  = nil
            case rendering_egine
            when 'latex'
              # Parse data to produce LateX
              data = data.gsub(/\\input/,'input not supported')
              data = data.gsub(/\\includegraphics(\*|)(\[[^\{]*\]|)\{([^\}]*?)(\.(\w+)|)\}/) do
                cmd_name = "includegraphics#{$1}"
                img_opts = $2
                img_id   = $3
                img_mode = $5
                if id = Node.translate_pseudo_id(img_id)
                  img = secure(Image) { Image.find_by_id(id) }
                  if img
                    if img_mode
                      format = Iformat[img_mode]
                      img_path = img.filepath(format)
                      if !File.exists?(img_path)
                        img_file = img.file(format) # force rendering of image
                        img_file.close
                      end
                    else
                      img_path = img.filepath(nil)
                    end
                  end
                  "\\includegraphics#{img_opts}{#{img_path}}"
                else
                  "(image '#{img_id}' not found)"
                end
              end

              tempf = Tempfile.new("#{@node[:id]}_#{@node.version.lang}")
              tex_path = "#{tempf.path}.tex"
              pdf_path = "#{tempf.path}.pdf"
              File.open(tex_path, 'wb') { |f| f.syswrite(data) }
              if !system("pdflatex -halt-on-error -output-directory '#{File.dirname(tex_path)}' '#{tex_path}' &> '#{tempf.path}'")
                failure = tempf.read
              end
            when 'fop'
              # FOP rendering
              xml_path  = "#{tempf.path}.xml"
              fo_path   = "#{tempf.path}.fo"

              # write xml to file
              File.open(xml_path, 'wb') { |f| f.syswrite(data) }

              # find stylesheet path is in the zafu folder
              xsl_path = template_path.sub(/\.erb\Z/,'.xsl')
              raise Excpetion.new("xsl content not found #{xsl_path.inspect} while rendering #{template_path.inspect} (node #{@node[:id]})") unless File.exist?(xsl_path)

              # run xsl with 'xml' content and stylesheet ==> 'xsl-fo' file
              if !system("xsltproc -o '#{fo_path}' '#{xsl_path}' '#{xml_path}' &> '#{tempf.path}'")
                failure = tempf.read
              else
                # run fop ==> PDF
                if !system("fop '#{fo_path}' '#{pdf_path}' &> '#{tempf.path}'")
                  failure = tempf.read
                end
              end
            end

            if !failure
              if data =~ /<!-- xsl_id:(\d+)/
                # make sure changes in xsl stylesheet expires cached PDF
                expire_with_ids = visitor.visited_node_ids + [$1.to_i]
              else
                expire_with_ids = visitor.visited_node_ids
              end

              data = File.read(pdf_path)
              # cache pdf data
              filepath = filepath[(SITES_ROOT.size)..-1]
              secure!(CachedPage) { CachedPage.create(:expire_after => nil, :path => filepath, :content_data => data, :node_id => @node[:id], :expire_with_ids => expire_with_ids) }
              send_data( data , :filename=>@node.title, :type => content_type, :disposition=>'inline')
            else
              # failure: send log
              send_data( failure , :filename=>"#{@node.title} - error", :type => 'text/plain', :disposition=>'inline')
            end
            #system("rm -rf #{tempf.path.inspect} #{(tempf.path + '.*').inspect}")
          end
        end

      end # ControllerMethods
    end # Rendering
  end # Use
end # Zena