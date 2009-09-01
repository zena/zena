require 'tempfile'
require 'json'

class ApplicationController < ActionController::Base
  include Zena::Use::Authentification::ControllerMethods
  include Zena::Use::ErrorRendering::ControllerMethods
  include Zena::Use::HtmlTags::ControllerMethods
  include Zena::Use::I18n::ControllerMethods
  include Zena::Use::Refactor::ControllerMethods
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::Urls::ControllerMethods
  include Zena::Use::Zafu::ControllerMethods
  
  helper  Zena::Use::Ajax::ViewMethods
  helper  Zena::Use::Calendar::ViewMethods
  helper  Zena::Use::ErrorRendering::ViewMethods
  helper  Zena::Use::HtmlTags::ViewMethods
  helper  Zena::Use::I18n::ViewMethods
  helper  Zena::Use::Refactor::ViewMethods
  helper  Zena::Use::Urls::ViewMethods
  helper  Zena::Use::Zafu::ViewMethods
  helper  Zena::Use::Zazen::ViewMethods
  
  helper_method :node_url, :notes, :error_messages_for, :render_errors, :processing_error
  helper_method :get_template_text, :template_url_for_asset, :save_erb_to_url, :lang, :visitor, :fullpath_from_template_url, :format_date, :get_table_from_json
  before_filter :set_lang
  before_filter :authorize
  before_filter :check_lang
  after_filter  :set_encoding
  layout false
  
  private
  
  
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
      if Thread.current.respond_to?(:visitor) && Thread.current.visitor
        # page not found
        @node = current_site.root_node
        respond_to do |format|
          format.html do
            if File.exists?("#{SITES_ROOT}/#{current_site.host}/public/#{prefix}/404.html")
              render :file => "#{SITES_ROOT}/#{current_site.host}/public/#{prefix}/404.html", :status => '404 Not Found'
            else
              render_and_cache :mode => '+notFound', :format => 'html', :cache_url => "/#{prefix}/404.html", :status => '404 Not Found'
            end
          end
          format.all  { render :nothing => true, :status => "404 Not Found" }
        end
      else
        # site not found
        respond_to do |format|
          format.html { render :file    => "#{RAILS_ROOT}/app/views/nodes/404.html", :status => '404 Not Found' }
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
=begin
      msg =<<-END_MSG
Something bad happened to your zena installation:
--------------------------
#{exception.message} 
--------------------------
#{exception.backtrace.join("\n")}
END_MSG
=end
      respond_to do |format|
        format.html { render :file    => "#{RAILS_ROOT}/app/views/nodes/500.html", :status => '500 Error' }
        format.all  { render :nothing => true, :status => "500 Error" }
      end
    end
  
    # TODO: test
    def visitor
      @visitor ||= returning(User.make_visitor(:host => request.host, :id => session[:user])) do |user|
        if session[:user] != user[:id]
          # changed user (login/logout)
          session[:user] = user[:id]
        end
        if user.is_anon?
          user.ip = request.headers['REMOTE_ADDR']
        end
      end
    end
        
    # TODO: test
    def lang
      visitor.lang
    end
    
    def render_and_cache(options={})
      opts = {:skin=>@node[:skin], :cache=>true}.merge(options)
      opts[:mode  ] ||= params[:mode]
      opts[:format] ||= params[:format].blank? ? 'html' : params[:format]
      
      # cleanup before rendering
      params.delete(:mode)
      
      if opts[:format] != 'html'
        content_type  = (EXT_TO_TYPE[opts[:format]] || ['application/octet-stream'])[0]
        template_path = template_url(opts)
        data = render_to_string(:file => template_path, :layout=>false)
        # TODO: use plugins...
        if opts[:format] == 'pdf' && ((ENABLE_LATEX && data =~ /\A% (latex)\n/) || (ENABLE_FOP && data =~ /\A<\?(xml)/))
          rendering_egine = $1 == 'xml' ? 'fop' : $1
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
            send_data( data , :filename=>@node.v_title, :type => content_type, :disposition=>'inline')
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
                      img_path = img.c_filepath(format)
                      if !File.exists?(img_path)
                        img_file = img.c_file(format) # force rendering of image
                        img_file.close
                      end
                    else
                      img_path = img.c_filepath(nil)
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
              send_data( data , :filename=>@node.v_title, :type => content_type, :disposition=>'inline')
            else
              # failure: send log
              send_data( failure , :filename=>"#{@node.v_title} - error", :type => 'text/plain', :disposition=>'inline')
            end
            #system("rm -rf #{tempf.path.inspect} #{(tempf.path + '.*').inspect}")
          end
        else
          # no post-rendering
          filepath = nil
          send_data( data , :filename=>@node.v_title, :type => content_type, :disposition=>'inline')
        end
        cache_page(:content_data => (failure || data), :content_path => filepath) if opts[:cache]
      else
        # html
        render :file => template_url(opts), :layout=>false, :status => opts[:status]
        cache_page(:url => opts[:cache_url]) if opts[:cache]
      end

    end
  
    # Cache page content into a static file in the current sites directory : SITES_ROOT/test.host/public
    def cache_page(opts={})
      return unless perform_caching && caching_allowed(:authenticated => opts.delete(:authenticated))
      opts = {:expire_after  => nil,
              :path          => (current_site.public_path + page_cache_file(opts.delete(:url))),
              :content_data  => response.body,
              :node_id       => @node[:id]
              }.merge(opts)
      secure!(CachedPage) { CachedPage.create(opts) }
    end
  
    # Return true if we can cache the current page
    def caching_allowed(opts = {})
      return false if current_site.authentication? || query_params != {}
      opts[:authenticated] || visitor.is_anon?
    end
  
    # Cache file path that reflects the called url
    def page_cache_file(url = nil)
      path = url || url_for(:only_path => true, :skip_relative_url_root => true)
      path = ((path.empty? || path == "/") ? "/index" : URI.unescape(path))
      ext = params[:format].blank? ? 'html' : params[:format]
      path << ".#{ext}" unless path =~ /\.#{ext}$/
      path
    end
    
    # Find the best template for the current node's skin, node's class, format and mode. The template
    # files are searched first into 'sites/shared/views/templates/fixed'. If the templates are not found
    # there, they are searched in the database and compiled into 'app/views/templates/compiled'.
    def template_url(opts={})
      @skin_name = opts[:skin]   || (@node ? @node[:skin] : nil) || 'default'
      @skin_name = @skin_name.url_name # security
      mode      = opts[:mode]
      format    = opts[:format] || 'html'
      klass     = @node.vclass
      
      # possible classes for the master template :
      klasses = []
      klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }
      
      # FIXME: is searching in all skins a good idea ? I think not. Only searching for special modes '+popupLayout', '+login', etc.
      if mode && mode[0..0] == '+'
        template = secure(Template) { Template.find(:first, 
          :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id", klasses, format, mode],
          :from       => "nodes, template_contents",
          :select     => "nodes.*, template_contents.skin_name, template_contents.klass, (template_contents.skin_name = #{@skin_name.inspect}) AS skin_ok",
          :order      => "length(tkpath) DESC, skin_ok DESC"
        )}
      else
        template = secure(Template) { Template.find(:first, 
          :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id AND template_contents.skin_name = ?", klasses, format, mode, @skin_name],
          :from       => "nodes, template_contents",
          :select     => "nodes.*, template_contents.skin_name, template_contents.klass",
          :order      => "length(tkpath) DESC"
        )}
      end
      
      # FIXME use a default fixed template.
      raise ActiveRecord::RecordNotFound unless template
      
      lang_path = session[:dev] ? "dev_#{lang}" : lang
      
      skin_path = "/#{@skin_name}/#{template[:name]}"  
      fullpath  = skin_path + "/#{lang_path}/_main.erb"
      rel_url   = 'zafu'     + current_site.zafu_path + fullpath  # relative to app/views
      url       = SITES_ROOT + current_site.zafu_path + fullpath  # absolute path

      if !File.exists?(url) || params[:rebuild]
        # no template ---> render
        # clear :
        # TODO: we should remove info in cached_page for _main
        FileUtils::rmtree(File.dirname(url))
        
        # set the places to search for the included templates
        # FIXME: there might be a better way to do this. In a hurry, fix later.
        @skin       = {}
        @skin_names = [@skin_name]
        secure!(Skin) { Skin.find(:all, :order=>'position ASC, name ASC') }.each do |s|
          @skin[s.name] = s
          next if s.name == @skin_name # do not add it twice
          @skin_names << s.name
        end
        @skin_link  = zen_path(@skin[@skin_name]) # used to link from <r:design/> zafu tag
        @expire_with_nodes = {}
        @renamed_assets    = {}
        
        res = ZafuParser.new_with_url(skin_path, :helper => zafu_helper).render(:dev => session[:dev])
        
        unless valid_template?(res, opts)
          # problem during rendering, use default zafu
          res = ZafuParser.new(default_zafu_template(mode), :helper => zafu_helper).render
        end
        
        if session[:dev] && mode != '+popupLayout'
          # add template edit buttons
          used_nodes  = []
          zafu_nodes  = []
          image_nodes = []
          asset_nodes = []
          @expire_with_nodes.merge(@renamed_assets).each do |k, n|
            if n.kind_of?(Image)
              image_nodes << [k,n]
            elsif n.kind_of?(Template)
              zafu_nodes  << [k,n]
            else
              asset_nodes << [k,n]
            end
          end
          used_nodes << ['zafu',    zafu_nodes] unless zafu_nodes.empty?
          used_nodes << ['images', image_nodes] unless image_nodes.empty?
          used_nodes << ['assets', asset_nodes] unless asset_nodes.empty?
          
          dev_box = "<div id='dev'><ul>\n"
          used_nodes.each do |name, nodes|
            dev_box << "  <li><a class='group' onclick='$(\"_dev_#{name}\").toggle();' href='#'>#{name}</a>\n"
            dev_box << "  <table id='_dev_#{name}'#{name == 'images' ? " style='display:none;'" : ''}>\n"
            nodes.each do |k,n|
              dev_box << "    <tr><td class='actions'>#{zafu_helper.send(:node_actions, :node=>n)}</td><td>#{zafu_helper.send(:link_to,k,zen_path(n))}</td></tr>\n"
            end
            dev_box << "  </table>\n"
            dev_box << "  </li>\n"
          end
          
          dev_box << "  <li><a class='group' onclick='$(\"_dev_tools\").toggle();' href='#'>tools</a>\n"
          dev_box << "    <ul id='_dev_tools' style='display:none;'>\n"
          dev_box << "      <li><a href='?rebuild=true'>#{_('rebuild')}</a></li>\n"
          dev_box << "<% if @node.kind_of?(Skin) -%>      <li><a href='<%= export_node_path(@node[:zip]) %>'>#{_('export')}</a></li>\n<% end -%>"
          dev_box << "      <li><a href='/users/#{visitor[:id]}/swap_dev'>#{_('turn dev off')}</a></li>\n"
          dev_box << "      <li>skins used: #{@skin_names.join(', ')}</li>\n"
          dev_box << "    <ul>\n  </li>\n</ul></div>"
          res.sub!('</body>', "#{dev_box}</body>")
        end
        
        secure!(CachedPage) { CachedPage.create(
          :path            => (current_site.zafu_path + fullpath),
          :expire_after    => nil,
          :expire_with_ids => @expire_with_nodes.values.map{|n| n[:id]},
          :node_id         => template[:id],
          :content_data    => res) }
      end
    
      return rel_url
    end
  
    def zafu_helper
      @zafu_helper ||= begin
        # FIXME rails 3.0.pre: zafu_helper = ActionView::Base.for_controller(self)
        helper = ActionView::Base.new([], {}, self)
        helper.helpers.send :include, self.class.master_helper_module
        helper
      end
    end
    # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
    # first element with the current skin_name and if it does not work, we try with the full url. If the url
    # start with a '/' we use the full url directly.
    # tested in MainControllerTest
    def get_template_text(opts)
      return nil unless res = find_document_for_template(opts)
      doc, url = *res
      # TODO: could we use this for caching or will we loose dynamic context based loading ?
      @expire_with_nodes[url] = doc
      text = session[:dev] ? doc.version.text : doc.version(:pub).text
      return text, url, doc
    end
    
    # Return the zen_path ('/en/image34.png') for an asset given its name ('img/footer.png').
    # The rule is not the same whether we are rendering a template and find <img/> <link rel='stylesheet'/> tags
    # or if we are parsing assets in a CSS file.
    def template_url_for_asset(opts)
      src = opts[:src]
      if src =~ /\A(.*)\.(\w+)\Z/
        src, format = $1, $2
      end
      
      if opts[:parse_assets]  
        current_folder = opts[:current_folder] || ''
        current_folder = current_folder[1..-1] if current_folder[0..0] == '/'
        
        if src =~ /\A(.*)_(\w+)\Z/
          # if the element was not found, maybe it was not a name with underscore but it was an image mode
          src2, mode2 = $1, $2
        end

        if src[0..0] == '/'
          path1 = src[1..-1]
          path2 = src2[1..-1] if src2
        else
          path1 = current_folder + '/' + src
          path2 = current_folder + '/' + src2 if src2
        end

        # make sure path elements are url_names
        path1 = path1.split('/').map {|s| s.url_name!}.join('/')
        path2 = path2.split('/').map {|s| s.url_name!}.join('/') if src2
        
        if asset = secure(Document) { Document.find_by_path(path1) }
        elsif src2 && (asset = secure(Document) { Document.find_by_path(path2) })
          mode = mode2
        else
          return nil
        end
      else
        if src =~ /\A(.*)_(\w+)\Z/
          src, mode = $1, $2
        end
        
        src2 = opts[:src].split('/').map {|s| s.url_name!}.join('/')
        
        unless res = find_document_for_template(opts)
          # '_...' did not mean mode but was an old name.
          mode = nil
          return nil unless res = find_document_for_template(opts.merge(:src => src2))
        end
        
        asset, url = *res
        @renamed_assets[url] = asset
      end
      
      data_path(asset, :mode => mode)
    end
    
    # opts should contain :current_template and :src. The source is a path like 'default/Node-+index'
    # ('skin/template/path'). If the path starts with a slash, the skin_name in the path is searched first. Otherwise,
    # the current skin is searched first.
    # <r:include template='Node'/>
    #   find: #{skin_path(main_skin)}/Node
    # 
    # <r:include template='/default/Node'/>
    #   find: #{skin_path('default')}/Node
    # 
    def find_document_for_template(opts)
      src    = opts[:src]
      if src =~ /\A(.*)\.(\w+)\Z/
        src, format = $1, $2
      end
      
      if src =~ /\A(.*)_(\w+)\Z/
        src, mode = $1, $2
      end
      
      folder = (opts[:current_folder] && opts[:current_folder] != '') ? opts[:current_folder].split('/') : []
      @skin ||= {}
      if src =~ /^\//
        # starts with '/' : look here first
        url = src[1..-1].split('/')
        name = url.shift
        skin_names = opts[:parse_assets] ? [name] : ([name] + (@skin_names - [name]))
      else
        # does not start with '/' : look in current skin first
        url = folder + src.split('/')
        skin_names = opts[:parse_assets] ? [] : @skin_names.dup
        if url.size > 1
          name = url.shift
          skin_names << name unless skin_names.include?(name)
        end
      end
      document = skin_name = nil
      [false, true].each do |rebuild_path|
        # try to find using cached fullpath first.
        skin_names.each do |skin_name|
          next unless skin = @skin[skin_name] ||= secure(Skin) { Skin.find_by_name(skin_name) }
          path = (skin.fullpath(rebuild_path).split('/') + url).join('/')
          break if document = secure(Document) { Document.find_by_path(path) }
        end
        break if document
      end
      if format == 'data' && document
        format = document.c_ext
      end
      return document ? [document, (([skin_name] + url).join('/') + (mode ? "_#{mode}" : '') + (format ? ".#{format}" : ''))] : nil
    end

    # TODO: test
    def save_erb_to_url(template, template_url)
      path = fullpath_from_template_url(template_url)
      path += ".erb" unless path =~ /\.\w+\Z/
      FileUtils.mkpath(File.dirname(path)) unless File.exists?(File.dirname(path))
      File.open(path, "wb") { |f| f.syswrite(template) }
      ""
    end
    
    # TODO: test
    def fullpath_from_template_url(template_url=params[:t_url])
      if template_url =~ /\A\.|[^\w\+\._\-\/]/
        raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
      end
      
      template_url = template_url[1..-1].split('/')
      path = "/#{template_url[0]}/#{template_url[1]}/#{session[:dev] ? "dev_#{lang}" : lang}/#{template_url[2..-1].join('/')}"

      "#{SITES_ROOT}/#{current_site.host}/zafu#{path}"
    end
    
    # Require a login for authenticated navigation (with '/oo' prefix) or for any content if the site's 'authorize'
    # attribute is true.
    def authorize
      return true if params[:controller] == 'session' && ['create', 'new', 'destroy'].include?(params[:action])
      
      # Require a login if :
      # 1. site forces authentication or navigation in '/oo'
      if (current_site.authentication? || params[:prefix] == AUTHENTICATED_PREFIX) && visitor.is_anon?
        return false unless do_login
      end
    end
    
    def do_login
      if current_site[:http_auth]
        session[:after_login_url] = request.parameters
        basic_auth_required do |username, password| 
          if user = User.make_visitor(:login => username, :password => password, :site => current_site)
            successful_login(user)
            return true
          end
        end
      else
        session[:after_login_url]   ||= request.parameters
        flash[:notice] = _("Please log in")
        redirect_to login_path and return false
      end
    end
    
    def successful_login(user)
      session[:user] = user[:id]
      session[:lang] = user.lang
      
      @visitor = user
      
      after_login_url = session[:after_login_url]
      session[:after_login_url] = nil
      if current_site[:http_auth] && params[:controller] != 'session'
        # no need to redirect
      else
        redirect_to after_login_url || user_path(visitor)
        return false
      end
    end
    
    # code adapted from Stuart Eccles from act_as_railsdav plugin
    def basic_auth_required(realm=current_site.name) 
      username, passwd = get_auth_data
      # check if authorized
      # try to get user
      if yield username, passwd
        true
      else
        # the user does not exist or the password was wrong
        headers["Status"] = "Unauthorized" 
        headers["WWW-Authenticate"] = "Basic realm=\"#{realm}\""
        
        # require login
        if current_site.authentication?
          render :nothing => true, :status => 401
        else
          redirect_url = session[:after_login_url] ? url_for(session[:after_login_url].merge(:prefix => session[:lang])) : '/'
          render :text => "
          <html>
            <head>
            <script type='text/javascript'>
            <!--
            window.location = '#{redirect_url}'
            //-->
            </script>
            </head>
            <body>redirecting to <a href='#{redirect_url}'>#{redirect_url}</a></body>
            </html>", :status => 401
        end
        false
      end 
    end 
    
    # code from Stuart Eccles from act_as_railsdav plugin
    def get_auth_data 
      user, pass = '', '' 
      # extract authorisation credentials 
      if request.env.has_key? 'X-HTTP_AUTHORIZATION' 
        # try to get it where mod_rewrite might have put it 
        authdata = request.env['X-HTTP_AUTHORIZATION'].to_s.split 
      elsif request.env.has_key? 'HTTP_AUTHORIZATION' 
        # this is the regular location 
        authdata = request.env['HTTP_AUTHORIZATION'].to_s.split  
      end 

      # at the moment we only support basic authentication 
      if authdata and authdata[0] == 'Basic' 
        user, pass = Base64.decode64(authdata[1]).split(':')[0..1] 
      end 
      return [user, pass] 
    end
    
  
    # Choose best language to display content.
    # 1. 'test.host/oo?lang=en' use 'lang', redirect without lang
    # 3. 'test.host/oo' use visitor[:lang]
    # 4. 'test.host/'   use session[:lang]
    # 5. 'test.host/oo' use visitor lang
    # 6. 'test.host/'   use HTTP_ACCEPT_LANGUAGE
    # 7. 'test.host/'   use default language
    #
    # 8. 'test.host/fr' the redirect for this rule is called once we are sure the request is not for document data (lang in this case can be different from what the visitor is visiting due to caching optimization)
    def set_lang
      if params[:prefix] =~ /^\d+$/
        # this has nothing to do with set_lang...
        # 'test.host/34' --> /en/node34.html
        redirect_to "/#{prefix}/#{params[:prefix]}"
        return false
      end
      
      chosen_lang = nil
      [
        params[:lang],
        visitor.is_anon? ? session[:lang] : visitor.lang,
        (request.headers['HTTP_ACCEPT_LANGUAGE'] || '').split(',').sort {|a,b| (b.split(';q=')[1] || 1.0).to_f <=> (a.split(';q=')[1] || 1.0).to_f }.map {|l| l.split(';')[0].split('-')[0] },
        (visitor.is_anon? ? visitor.lang : nil), # anonymous user's lang comes last
      ].compact.flatten.uniq.each do |l|
        if current_site.lang_list.include?(l)
          chosen_lang = l
          break
        end
      end
      
      set_visitor_lang(chosen_lang || current_site[:default_lang])
      true
    end
    
    def set_visitor_lang(l)
      return unless current_site.lang_list.include?(l)
      session[:lang] = l
      
      if visitor.lang != l && !visitor.is_anon?
        visitor.site_participation.update_attribute('lang', l)
      else
        visitor.lang = l
      end
      
      l = 'en' unless File.exist?("#{RAILS_ROOT}/locale/#{l}/LC_MESSAGES/zena.mo")
      
      FastGettext.text_domain = 'zena'
      FastGettext.available_locales = current_site.lang_list
      FastGettext.locale = l
    end
    
    # Redirect on lang change "...?lang=de"
    def check_lang
      if params[:lang]
        # redirects other controllers (users controller, etc)
        redirect_url = params
        redirect_url.delete(:lang)
        if params[:controller] == 'nodes'
          redirect_to redirect_url.merge(:prefix => prefix) and return false
        else
          redirect_to redirect_url and return false
        end
      end
      true
    end
  
    def set_encoding
      headers['Content-Type'] ||= 'text/html'
      if headers['Content-Type'].starts_with?('text/') and !headers['Content-Type'].include?('charset=')
        headers['Content-Type'] += '; charset=utf-8'
      end
    end
    
    # /////// The following methods are common to controllers and views //////////// #
  
    # Restrict access some actions to administrators (used as a before_filter)
    def check_is_admin
      render_404(ActiveRecord::RecordNotFound) unless visitor.is_admin?
      @admin = true
    end
  
    #TODO: test
    def error_messages_for(obj, opts={})
      return '' if obj.errors.empty?
      res = ["<table class='#{opts[:class] || 'errors'}'>"]
      obj.errors.each do |er,msg|
        res << "<tr><td><b>#{er}</b></td><td>#{_(msg)}</td></tr>"
      end
      res << '</table>'
      res.join("\n")
    end
  
    # TODO: test (where is this used ? discussions, ?)
    def processing_error(msg)
      # (this method used to be called add_error, but it messed up with 'test/unit/testcase.rb' when testing helpers)
      @errors ||= []
      @errors << _(msg)
    end
  
    # TODO: test
    def render_errors(errs=@errors)
      if !errs || errs.empty?
        ""
      elsif errs.kind_of?(ActiveRecord::Errors)
        res = "<table class='errors'>"
        errs.each do |k,v|
          res << "<tr><td><b>#{k}</b></td><td>#{v}</td></tr>\n"
        end
        res << "</table>"
        res
      else
        "<table class='errors'><tr><td>#{errs.join("</td></tr>\n<tr><td>")}</td></tr></table>"
      end
    end
  
    # Find the proper layout to render 'admin' actions. The layout is searched into the visitor's contact's skin first
    # and then into default. This action is also responsible for setting a default @title_for_layout.
    def admin_layout
      @title_for_layout ||= "#{params[:controller]}/#{params[:action]}"
      template_url(:mode=>'+adminLayout')
    end
  
    # TODO: test
    def popup_layout
      template_url(:mode=>'+popupLayout')
    end
    
    def format_date(thedate, theformat = nil, tz_name=nil, lang=visitor.lang)
      format = theformat || '%Y-%m-%d %H:%M:%S'
      return "" unless thedate
      if tz_name
        # display time local to event's timezone
        begin
          tz = TZInfo::Timezone.get(tz_name)
        rescue TZInfo::InvalidTimezoneIdentifier
          return "<span class='parser_error'>invalid timezone #{tz_name.inspect}</span>"
        end
      else
        tz = visitor.tz
      end
      if thedate.kind_of?(Time)
        utc_date = thedate
        adate = tz.utc_to_local(thedate)
      elsif thedate.kind_of?(String)
        begin
          adate    = Date.parse(thedate)
          utc_date = adate

        rescue
          # only return error if there is a format (without = used in sql query)
          return theformat ? "<span class='parser_error'>invalid date #{thedate.inspect}</span>" : Time.now.strftime('%Y-%m-%d %H:%M:%S')
        end
      else
        adate    = thedate
        utc_date = adate
      end
      
      if visitor.lang != lang
        GetText.set_locale_all(lang)
      end
      if format =~ /^age\/?(.*)$/
        format = $1.blank? ? _('long_date') : $1
        # how long ago/in how long is the date
        # FIXME: when using 'age', set expire_at (+1 minute, +1 hour, +1 day, never)
        age = (Time.now.utc - utc_date) / 60
        
        if age > 7 * 24 * 60
          # far in the past, use strftime
        elsif age >= 2 * 24 * 60
          # days
          return _("%{d} days ago") % {:d => (age/(24*60)).floor}
        elsif age >= 24 * 60
          # days
          return _("yesterday")
        elsif age >= 2 * 60
          # hours
          return _("%{h} hours ago") % {:h => (age/60).floor}
        elsif age >= 60
          return _("1 hour ago")
        elsif age > 2
          # minutes
          return _("%{m} minutes ago") % {:m => age.floor}
        elsif age > 0
          return _("1 minute ago")
        elsif age >= -1
          return _("in 1 minute")
        elsif age > -60
          return _("in %{m} minutes") % {:m => -age.ceil}
        elsif age > -2 * 60
          return _("in 1 hour")
        elsif age > -24 * 60
          return _("in %{h} hours") % {:h => -(age/60).ceil}
        elsif age > -2 * 24 * 60
          return _("tomorrow")
        elsif age > -7 * 24 * 60
          return _("in %{d} days") % {:d => -(age/(24*60)).ceil}
        else
          # too far in the future, use strftime
        end
      end
      
      # month name
      format = format.gsub("%b", _(adate.strftime("%b")) )
      format.gsub!("%B", _(adate.strftime("%B")) )
      
      # weekday name
      format.gsub!("%a", _(adate.strftime("%a")) )
      format.gsub!("%A", _(adate.strftime("%A")) )
      
      if visitor.lang != lang
        GetText.set_locale_all(visitor.lang)
      end
      
      adate.strftime(format)
    end
    
    # Read the parameters and add errors to the object if it is considered spam. Save it otherwize.
    def save_if_not_spam(obj, params)
      # do nothing (overwritten by plugins like zena_captcha)
      obj.save
    end
    
    # Url parameters (without format/mode/prefix...)
    def query_params
      res = {}
      path_params.each do |k,v|
        next if [:mode, :format, :asset].include?(k.to_sym)
        res[k.to_sym] = v
      end
      res
    end
    
    # Url parameters (without action,controller,path,prefix)
    def path_params
      res = {}
      params.each do |k,v|
        next if [:action, :controller, :path, :prefix, :id].include?(k.to_sym)
        res[k.to_sym] = v
      end
      res
    end
    
    # Build a tabular content from a node's attribute
    def get_table_from_json(node, attribute)
      text = Node.zafu_attribute(node, attribute)
      if text.blank?
        table = [{"type"=>"table"},[["title"],["value"]]]
      else
        table = JSON.parse(text)
      end
      raise JSON::ParserError unless table.kind_of?(Array) && table.size == 2 && table[0].kind_of?(Hash) && table[0]['type'] == 'table' && table[1].kind_of?(Array)
      table
    end
    
    # Make sure some vital templates never get broken
    def valid_template?(content, opts)
      mode = opts[:mode]
      case mode
      when '+login'
        content =~ %r{<form[^>]* action\s*=\s*./session}
      when '+adminLayout'
        content =~ %r{<%= content_for_layout %>} && %r{show_link(:admin_links)}
      else
        true
      end
    end
    
    # Default template content for a specified mode
    def default_zafu_template(mode)
      if mode =~ /\A\.|[^\w\+\._\-\/]/
        raise Zena::AccessViolation.new("'mode' contains illegal characters : #{mode.inspect}")
      end
      File.read(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'defaults', "#{mode}.zafu"))
    end
end

Bricks::Patcher.apply_patches
