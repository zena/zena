=begin rdoc
=== Url

 basepath          class and zip   optional mode   format
 
 /projects/art/    project24       -print          .html

Examples:
 /current/art/project24.html            << a project inside the 'art' page
 /note24.html                           << a Note's page
 /note24_print.html                     << a Note in 'print' mode
 /current/art.html                      << 'art' page (this page has custom base set = no class or zip shown)
 /current/art-print.html                << 'art' page in 'print' mode
 /current/art/project24/image28.html    << image page (for comments, etc)
 /current/art/project24/image28.jpg     << full image
 /current/art/project24/image28_pv.jpg  << image in the 'pv' format
 /current/art/project24/image28_pv.html << image page in 'print' mode
 
=end
class NodesController < ApplicationController
  before_filter :check_is_admin, :only => [:export]
  before_filter :find_node, :except => [:index, :create, :not_found, :catch_all, :search, :attribute]
  before_filter :check_path, :only  => [:index, :show]
  after_filter  :change_lang, :only => [:create, :update, :save_text]
  layout :popup_layout,     :only   => [:edit, :import]
  
  def index
    @node = current_site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => '*index' }
      format.xml  { render :xml => @node.to_xml }
    end
  end
  
  # Render badly formed urls
  def catch_all
    url_params_list = []
    url_params.each do |k,v|
      url_params_list << "#{k}=#{CGI.escape(v)}"
    end
    redirect_to "/" + ([prefix]+params[:path]).flatten.join('/') + (url_params_list == [] ? '' : "?#{url_params_list.join('&')}")
  end
  
  # This method is used to test the 404 page when editing zafu templates. It is mapped from '/en/404.html'.
  def not_found
    raise ActiveRecord::RecordNotFound
  end
  
  def search
    do_search
    respond_to do |format|
      format.html { render_and_cache :mode => '*search', :cache => false }
      format.js
    end
  end
  
  # this should not be needed.... but format.js never gets called otherwize.
  def asearch
    do_search
    respond_to do |format|
      #format.html { render_and_cache :mode => 'search' }
      format.js { render :action => 'search'}
    end
  end

  # There is a bug in prototype/rails/mongrel : accept_headers are wrong when doing an rjs 'get'.
  # remove this method + route when fixed.
  def zafu
    respond_to do |format|
      format.js { render :action => 'show' }
    end
  end
  
  # This method is called when an element is dropped on a node.
  def drop
    set       = params[:set]
    other_zip = params[:drop].split('_').last
    other  = secure!(Node) { Node.find_by_zip(other_zip)}
    
    if attributes = params[:node]
      if params[:node][:id] == '[id]'
        # swap (a way to preview content by drag & drop)
        @node = other
      elsif params[:change] == 'receiver'
        attributes[:copy] = other
        @node.update_attributes_with_transformation(attributes)
        if !@node.errors.empty?
          @errors = @node.errors
        end
      else
        attributes[:copy] = @node
        other.update_attributes_with_transformation(attributes)
        if !other.errors.empty?
          @errors = other.errors
        end
      end  
    elsif p = params[:params]
      params.merge!(other.replace_attributes_in_values(p))
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def show
    respond_to do |format|
      
      format.html { render_and_cache }
      
      format.js   { @template_file = fullpath_from_template_url(params[:template_url]) } # zafu ajax
      
      format.all  do
        if asset = params[:asset]
          # math rendered as png, ...
          filename     = "#{asset}.#{params[:format]}"
          content_path = @node.asset_path(filename)
          raise ActiveRecord::RecordNotFound unless File.exist?(content_path)
          data = File.new(content_path)
          content_type = (EXT_TO_TYPE[params[:format]] || ['application/octet-stream'])[0]
          send_data( data.read , :filename=>filename, :type => content_type, :disposition=>'inline')
          data.close
          cache_page(:content_path => content_path, :authenticated => @node.public?) # content_path is used to cache by creating a symlink
        elsif @node.kind_of?(Document) && params[:format] == @node.c_ext
          # Get document data (inline if possible)
        
          if @node.kind_of?(Image) && !ImageBuilder.dummy?
            if img_format = Iformat[params[:mode]]
              data = @node.c_file(img_format)
              content_path = @node.c_filepath(img_format)
            end
          elsif @node.kind_of?(TextDocument)
            data = StringIO.new(@node.v_text)
            content_path = nil
          else
            data         = @node.c_file
            content_path = @node.c_filepath
          end
          
          raise ActiveRecord::RecordNotFound unless data
        
          send_data( data.read , :filename=>@node.filename, :type => @node.c_content_type, :disposition=>'inline')
          data.close
          cache_page(:content_path => content_path, :authenticated => @node.public?) # content_path is used to cache by creating a symlink
        else
          render_and_cache
          # FIXME: redirect to document format should occur in render_and_cache
          #if has skin for format
          #  render_and_cache
          #elsif params[:format] == 'xml'
          #  render :xml => @node.to_xml }
          #else
          #  return redirect_to(zen_path(@node), :mode => params[:mode])
          #end
        end
      end
    end
  end
  
  def create
    attrs = params['node']
    @node = secure!(Node) { Node.create_node(attrs) }
    
    respond_to do |format|
      if @node.errors.empty?
        flash[:notice] = 'Node was successfully created.'
        format.html { redirect_to node_url(@node) }
        format.js
        format.xml  { head :created, :location => node_url(@node) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @node.errors.to_xml }
      end
    end
  end
  
  # modifications of the node itself (dates, groups, revert editions, etc)
  def edit
    respond_to do |format|
      format.html do
        @title_for_layout = @node.rootpath
      end
      format.js do
        # zafu edit
        render :template => 'nodes/edit.rjs' # FIXME: this should not be needed. Rails bug ?
      end
    end
  end
  
  # TODO: test
  def save_text
    update
  end
  
  # Create a backup copy of the current redaction.
  def backup
    @node = secure_write!(Node) { Node.version(params[:id]) }
    @node.backup
    if @node.errors.empty?
      flash[:notice] = _("Backup created.")
    else
      flash[:error] = _("Could not create backup.")
    end
  end
  
  # import sub-nodes from a file
  def import
    @nodes = secure!(Node) { Node.create_nodes_from_folder(:klass => params[:node][:klass], :archive => params[:node][:archive], :parent => @node) }.values
    
    if params[:node][:klass] == 'Skin'
      # update CSS files
      @nodes.each do |n|
        if n.c_ext == 'css'
          v_status = n.v_status
          text     = n.parse_assets(n.v_text, self)
          errors   = n.errors.dup
          n.errors.clear
          n.update_attributes(:v_status => v_status, :v_text => text)
        end
      end
    end
    @nodes
  end
  
  def export
    data = @node.archive
    send_data( data.read, :filename=>"#{@node.name}.tgz", :type => 'application/x-gzip')
    data.close
  end
  
  def update
    
    @node.update_attributes_with_transformation(params['node'])
    
    if @node.errors.empty?
      flash.now[:notice] = _('node updated')
    else
      flash.now[:error]  = _('could not update')
    end
    
    respond_to do |format|
      format.html do
        if params[:edit] == 'popup'
          redirect_to edit_version_url(:node_id => @node[:zip], :id=>(@node.v_number || 0), :close => (params[:validate] ? true : nil)) 
        else
          redirect_to zen_path(@node, :mode => params[:mode])
        end
      end
      format.js   { @flash = flash }
    end
  end
  
  # AJAX HELPER
  # TODO: test
  def attribute
    method = params[:attr].to_sym
    if [:v_text, :v_summary, :name, :path, :short_path].include?(method)
      # '+' are not escaped as they should in ajax query
      params[:node].sub!(/ +$/) {|spaces| '+' * spaces.length} if params[:node]
      node_id = secure!(Node) { Node.translate_pseudo_id(params[:node])}
      @node = secure!(Node) { Node.find(node_id) }
      
      if method == :path || method == :short_path
        path = @node.send(method)
        render :inline=> path.join('/ ')
      else
        @text = @node.send(method)
        if [:v_text, :v_summary].include?(method)
          render :inline=>"<%= zazen(@text) %>"
        else
          render :inline=>@text
        end
      end
    else
      render :inline=>method
    end
  rescue ActiveRecord::RecordNotFound
    render :inline=>_('node not found')
  end
  
  # TODO: test
  # change the position of the children of the current element.
  # TODO: what happens if not all the children are present due to access rights ?
  def order
    allOK = true
    positions = []
    params.each do |k,v|
      if k =~ /^sort_(.*)/
        positions = v
        break
      end
    end
    
    positions.each_with_index do |zip,idx|
      child = secure!(Node) { Node.find_by_zip(zip) }
      child.position = idx.to_f + 1.0
      allOk = child.save && allOK
    end
    
    respond_to do |format|
      if allOK
        format.html { render :text => _('Order updated')}
      else  
        format.html { render :text => _('Could not update order.')}
      end
    end
  end
  
  def clear_order
    kpath = (params[:kpath] || 'ZZ')[0..1]
    allOk = true
    
    children = secure!(Node) { Node.find(:all, :conditions => ['parent_id = ? AND kpath like ?', @node[:id], "#{kpath}%"])}
    
    children.each do |child|
      child.position = 0.0
      allOk = child.save && allOk
    end
    
    if !allOk
      @errors = _('Could not clear order.')
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  
  protected
    
    # Find a node based on the path or id. When there is a path, the node is found using the zip included in the path
    # or by fullpath:
    #  name              find by
    #  page23.html  ---> zip (23)
    #  2006         ---> fullpath
    #  2006.xml     ---> fullpath
    #  p34          ---> zip (34)
    #  10-25-2006   ---> fullpath
    #  archive-1    ---> fullpath
    #  archive      ---> fullpath
    def find_node
      if path = params[:path]
        if path.last =~ /\A(([a-zA-Z]+)([0-9]+)|([a-zA-Z0-9\-\*]+))(_[a-z]+|)(\..+|)\Z/
          zip    = $3
          name   = $4
          params[:mode] = $5 == '' ? nil : $5[1..-1]
          asset_and_format = $6 == '' ? '' : $6[1..-1]
          if asset_and_format =~ /(\w+)\.(\w+)/
            params[:asset ] = $1
            params[:format] = $2
          else
            params[:format] = asset_and_format
          end
          if name =~ /^\d+$/
            @node = secure!(Node) { Node.find_by_zip(name) }
          elsif name
            basepath = (path[0..-2] + [name]).join('/')
            @node = secure!(Node) { Node.find_by_path(basepath) }
          else
            @node = secure!(Node) { Node.find_by_zip(zip) }
          end
        else
          # bad url
          raise ActiveRecord::RecordNotFound
        end
      elsif params[:id]
        @node = secure!(Node) { Node.find_by_zip(params[:id]) }
      end
      
      if params[:link_id]
        @link = Link.find_through(@node, params[:link_id])
      end
      
      @title_for_layout = @node.rootpath if @node
    end

    def check_path
      case params[:action]
      when 'index'
        # bad prefix '/so', '/rx' or '/en?lang=fr'
        if params[:prefix] != prefix
          set_visitor_lang(params[:prefix])
          # redirect if new lang could not be set
          redirect_url = "/#{prefix}" if prefix != params[:prefix]
        end
      when 'show'
        # show must have a 'path' parameter
        
        if params[:prefix] != prefix && !avoid_prefix_redirect
          # lang changed
          set_visitor_lang(params[:prefix])
          redirect_url = zen_path(@node, path_params)
        elsif params[:path] != zen_path(@node, :format=>params[:format], :mode=>params[:mode], :asset=>params[:asset]).split('/')[2..-1]
          # badly formed url
          redirect_url = zen_path(@node, path_params)
        elsif params[:mode] == 'edit' && !@node.can_write?
          # special 'edit' mode
          redirect_url = zen_path(@node, :format => params[:format], :asset => params[:asset])
        end 
      end
      
      if redirect_url
        redirect_to redirect_url and return false
      end
      true
    end
    
    def check_can_drive
      if !@node.can_drive?
        @node.errors.add('base', 'you do not have the rights to do this')
      end
    end
    
    def change_lang
      set_visitor_lang(params[:node]['v_lang']) if params[:node] && params[:node]['v_lang']
    end
    
    def do_search
      @node = current_site.root_node
      query = Node.match_query(params[:q], :node => @node)
      
      @nodes = secure(Node) do
        @nodes_previous_page, @nodes, @nodes_next_page = Node.find_with_pagination(:all,query.merge(:per_page => 10, :page => params[:page]))
        @nodes # important: this is the 'secure' yield return, it is used to secure found nodes
      end
    end
    
    # Document data do not change session[:lang] and can point at cached content (no nee to redirect to AUTHENTICATED_PREFIX).
    def avoid_prefix_redirect
      @node.kind_of?(Document) && params[:format] == @node.c_ext
    end
    
    # Url parameters (without format/mode/prefix...)
    def url_params
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
end

