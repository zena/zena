=begin rdoc
=== Url

 basepath          class and zip   optional mode   format

 /projects/art/    project24       _print          .html

Examples:
 /current/art/project24.html            << a project inside the 'art' page
 /note24.html                           << a Note's page
 /note24_print.html                     << a Note in 'print' mode
 /current/art.html                      << 'art' page (this page has custom base set, this means no class or zip shown)
 /current/art_print.html                << 'art' page in 'print' mode
 /current/art/project24/image28.html    << image page (for comments, etc)
 /current/art/project24/image28.jpg     << full image data
 /current/art/project24/image28_pv.jpg  << image in the 'pv' image format
 /current/art/project24/image28_print.html << image page in 'print' mode

=end
class NodesController < ApplicationController
  before_filter :check_is_admin,  :only => [:export]
  before_filter :check_api_group
  before_filter :find_node, :except => [:index, :create, :not_found, :catch_all, :search]
  before_filter :check_can_drive, :only => [:edit]
  before_filter :check_path,      :only => [:index, :show]
  after_filter  :change_lang,     :only => [:create, :update, :save_text]
  layout :popup_layout,           :only => [:edit, :import]

  include Zena::Use::Grid::ControllerMethods

  def index
    @node = current_site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => '+index' }
      format.xml  { render :xml => @node.to_xml }
    end
  end

  # Render badly formed urls
  def catch_all
    query_params_list = []
    query_params.each do |k,v|
      next if v.kind_of?(Hash) # FIXME: we should support nested hashes. Can't we use something in rails here ?
      query_params_list << "#{k}=#{CGI.escape(v)}"
    end
    redirect_to "/" + ([prefix]+params[:path]).flatten.join('/') + (query_params_list == [] ? '' : "?#{query_params_list.join('&')}")
  end

  # This method is used to test the 404 page when editing zafu templates. It is mapped from '/en/404.html'.
  def not_found
    raise ActiveRecord::RecordNotFound
  end

  # Find nodes starting from root node
  def search
    respond_to do |format|
      format.html do
        begin
          do_search
        rescue QueryBuilder::Error => err
          flash[:error] = err.message
        end
        render_and_cache :mode => '+search', :cache => false
      end

      format.xml do
        begin
          do_search
          if @nodes.kind_of?(Fixnum)
            # count
            render :xml => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<count type=\"integer\">#{@nodes}</count>\n"
          elsif @nodes
            render :xml => Array(@nodes).to_xml(:root => 'nodes')
          else
            render :xml => [].to_xml(:root => 'nodes')
          end
        rescue QueryBuilder::Error => err
          render :xml => [{:message => err.message}].to_xml(:root => 'errors'), :status => 401
        end
      end

      format.js do
        do_search
        render :action => 'search'
      end
    end
  end

  # Find nodes starting from a given node
  def find
    search
  end

  # this should not be needed.... but format.js never gets called otherwize.
  def asearch
    do_search
    respond_to do |format|
      #format.html { render_and_cache :mode => 'search' }
      format.js { render :action => 'search'}
    end
  end

  # RJS method. show.js not working... ?
  # FIXME: remove.
  def zafu
    return self.update if params[:method] == 'put'
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

      if !params[:prefix]
        # /nodes/18.xml not treated the same as /en/page18.xml (render_and_cache)
        format.xml { render :xml => @node.to_xml }
      end

      format.any do
        if asset = params[:asset]
          # math rendered as png, ...
          filename     = "#{asset}.#{params[:format]}"
          content_path = @node.asset_path(filename)
          content_type = (Zena::EXT_TO_TYPE[params[:format]] || ['application/octet-stream'])[0]
          send_file(content_path, :filename=>filename, :type => content_type, :disposition=>'inline', :x_sendfile => ENABLE_XSENDFILE)
          cache_page(:content_path => content_path, :authenticated => @node.public?) # content_path is used to cache by creating a symlink
        elsif @node.kind_of?(Document) && params[:format] == @node.ext
          # Get document data (inline if possible)
          content_path = nil

          if @node.kind_of?(Image) && !Zena::Use::ImageBuilder.dummy?
            if img_format = Iformat[params[:mode]]
              content_path = @node.filepath(img_format)
              # force creation of image data
              @node.file(img_format)
            end
          elsif @node.kind_of?(TextDocument)
            send_data(@node.text, :filename => @node.filename, :type => 'text/css', :disposition => 'inline')
          else
            content_path = @node.filepath
          end

          if content_path
            # FIXME RAILS: remove 'stream => false' when rails streaming is fixed
            send_file(content_path, :filename => @node.filename, :type => @node.content_type, :disposition => 'inline', :stream => false, :x_sendfile => ENABLE_XSENDFILE)
          end

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
    file, file_error = get_attachment
    if file
      attrs['file'] = file
      attrs['klass'] = 'Document'
    end

    @node = secure!(Node) { Node.create_node(attrs) }
    @node.errors.add('file', file_error) if file_error

    respond_to do |format|
      if @node.errors.empty?
        flash[:notice] = 'Node was successfully created.'
        format.html { redirect_to zen_path(@node) }
        format.js
        format.xml  { render :xml => @node.to_xml(:root => 'node'), :status => :created, :location => node_url(@node) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @node.errors, :status => :unprocessable_entity }
      end
    end
  end

  # modifications of the node itself (dates, groups, revert editions, etc)
  def edit
    @node.load_roles!

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

  def destroy
    respond_to do |format|

      format.html do
        if @node.destroy
          flash[:notice] = "Node destroyed."
          redirect_to zen_path(@node.parent)
        else
          flash[:notice] = "Could not destroy node."
          render :action => 'show'
        end
      end

      format.xml  do
        node_xml = @node.to_xml #need to be allocated before destroying
        if node_xml && @node.destroy
          render :xml => node_xml, :status => 200
        else
          @node.errors.add(:visitor, visitor.login) if RAILS_ENV == 'development'
          render :xml => @node.errors, :status => :unprocessable_entity
        end
      end

      format.js

    end
  end

  # TODO: test
  def save_text
    update
  end

  # Create a backup copy of the current redaction.
  def backup
    version = secure_write!(Version) { Version.find(params[:id]) }
    @node   = version.node
    @node.backup
    if @node.errors.empty?
      flash[:notice] = _("Backup created.")
    else
      flash[:error] = _("Could not create backup.")
    end
  end

  # import sub-nodes from a file
  def import
    defaults = params[:node]
    klass = defaults.delete(:klass)
    if klass == 'Skin' && !defaults.has_key?('v_status')
      defaults['v_status'] = Zena::Status[:pub]
    end
    attachment, error = get_attachment
    if error
      responds_to_parent do
        page.replace 'form_errors', error
      end
    else
      # TODO: UploadProgress.setAsProcessing..... would be nice...
      @nodes = secure!(Node) { Node.create_nodes_from_folder(
        :klass    => klass,
        :archive  => attachment,
        :parent   => @node,
        :defaults => defaults
      )}.values
      # parse pseudo_ids
      parse_assets(@nodes)

      responds_to_parent do # execute the redirect in the main window
        render :update do |page|
          page.call 'UploadProgress.setAsFinished'
          page.delay(1) do # allow the progress bar fade to complete
            page.replace_html 'import_tab', :partial => 'import_results'
          end
        end
      end
    end
  end

  def export
    send_file(@node.archive.path, :filename=>"#{@node.name}.tgz", :type => 'application/x-gzip', :x_sendfile => ENABLE_XSENDFILE)
  end

  def update
    file, file_error = get_attachment
    params['node']['file'] = file if file

    @v_status_before_update = @node.v_status
    @node.update_attributes_with_transformation(params['node'])
    # What is this 'extfile' thing ?
    @node.errors.add('extfile', file_error) if file_error

    if @node.errors.empty?
      flash.now[:notice] = _('node updated')
    else
      flash.now[:error]  = _('could not update')
    end

    if params[:iframe]
      responds_to_parent do # execute the redirect in the iframe's parent window
        render :update do |page|
          page.call "UploadProgress.setAsFinished"
          page.delay(1) do # allow the progress bar fade to complete
            page.redirect_to edit_node_version_path(:node_id => @node[:zip], :id=>(@node.v_number || 0), :close => (params[:validate] ? true : nil))
          end
        end
      end # parent iframe (upload)
    elsif @node.errors.empty?
      respond_to do |format|
        format.html do
          if params[:edit] == 'popup'
            redirect_to edit_node_version_path(:node_id => @node[:zip], :id => 0, :close => (params[:validate] ? true : nil))
          else
            redirect_to zen_path(@node, :mode => params[:mode])
          end
        end # html

        format.js { @flash = flash }

        format.xml do
          if @node.errors.empty?
            render :xml => @node.to_xml, :status => :ok, :location => node_url(@node)
          else
            render :xml => @page.errors, :status => :unprocessable_entity
          end
        end # xml
      end
    end
  end

  # AJAX HELPER
  # TODO: test
  def attribute
    method = params[:attr]
    if (params[:pseudo_id] || params[:name]).blank? || !%w{title text summary name path short_path}.include?(method)
      # Error
      render :text => ''
      return
    end

    if id_query = params[:pseudo_id]
      # '+' are not escaped as they should in ajax query
      id_query.sub!(/ +$/) {|spaces| '+' * spaces.length }
      node_id = secure!(Node) { Node.translate_pseudo_id(id_query, :id, @node)}
      @node = secure!(Node) { Node.find(node_id) }
    elsif name_query = params[:name]
      if name_query =~ /^(.*)\.[a-z]{2,3}$/
        name_query = $1
      end

      conditions = [[]]

      if kpath = params[:kpath]
        conditions[0] << "kpath LIKE ?"
        conditions << "#{kpath}%"
      end

      conditions[0] << "node_name LIKE ?"
      conditions << "#{name_query}%"

      conditions[0] = conditions[0].join(' AND ')
      @node = secure!(Node) { Node.find(:first, :conditions => conditions, :order => "zip DESC")}
    end

    if %w{path short_path}.include?(method)
      path = @node.send(method)
      render :text => path.join('/ ')
    else
      @text = @node.send(method)
      if %w{text summary}.include?(method)
        render :text => "<%= zazen(@text) %>"
      else
        render :text => @text
      end
    end
  rescue ActiveRecord::RecordNotFound
    render :text => (params[:pseudo_id] ? _('node not found') : _('new'))
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
        if path.last =~ /\A(([a-zA-Z]+)([0-9]+)|([a-zA-Z0-9\-\*]+))(_[a-zA-Z]+|)(\..+|)\Z/
          zip    = $3
          name   = $4
          params[:mode] = $5 == '' ? nil : $5[1..-1]
          asset_and_format = $6 == '' ? '' : $6[1..-1]
          if asset_and_format =~ /(\w+)\.(\w+)/
            params[:asset ] = $1
            set_format($2)
          else
            set_format(asset_and_format)
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

    def set_format(format)
      request.instance_eval do
        parameters[:format] = format
        @env["action_dispatch.request.formats"] = [Mime::Type.lookup_by_extension(parameters[:format]) || Mime::Type.lookup_by_extension('bin')]
      end
    end

    # Make sure the current url is valid. If it is not, redirect.
    def check_path
      # show must have a 'path' parameter unless logged in and xml format
      if !params[:prefix] && request.format == Mime::XML
        # xml API
        return true
      end

      case params[:action]
      when 'index'
        # TODO: this should live in I18n (and maybe it is not needed anymore)
        # bad prefix '/so', '/rx' or '/en?lang=fr'
        if params[:prefix] != prefix
          set_visitor_lang(params[:prefix])
          # redirect if new lang could not be set
          if prefix != params[:prefix]
            # Invalid prefix
            redirect_to "/#{prefix}" and return false
          end
        end
      when 'show'

        if params[:format] != 'html' && params[:cachestamp].nil?
          # maybe not seen, try to find it
          params.each do |k,v|
            if k =~ /\A\d+\Z/ && v.nil?
              params[:cachestamp] = k
              params.delete(k)
              break
            end
          end
        end

        if params[:prefix] != prefix && !avoid_prefix_redirect
          # lang changed
          set_visitor_lang(params[:prefix])
          redirect_to zen_path(@node, path_params) and return false
        end

        current_url  = append_query_params("/#{params[:prefix]}/#{params[:path].join('/')}", :cachestamp => params[:cachestamp])
        base_url     = zen_path(@node,
          :prefix => params[:prefix],
          :format => params[:format],
          :mode   => params[:mode],
          :asset  => params[:asset])

        if current_url != base_url
          # Badly formed url, redirect
          redirect_to zen_path(@node, path_params) and return false
        end

        if cachestamp_format?(params[:format]) && params[:cachestamp] != make_cachestamp(@node, params[:mode])
          # Invalid cachestamp, redirect
          redirect_to zen_path(@node, path_params) and return false
        end

        if params[:mode] == 'edit' && !@node.can_write?
          # Not allowed to edit on special 'edit' mode
          redirect_to zen_path(@node, :format => params[:format], :asset => params[:asset]) and return false
        end
      end

      true
    end

    def check_can_drive
      if !@node.can_drive?
        @node.errors.add('base', 'You do not have the rights to do this.')
      end
    end

    def change_lang
      set_visitor_lang(params[:node]['v_lang']) if params[:node] && params[:node]['v_lang']
    end

    def do_search
      if @node
        default_scope = 'self'
      else
        @node = current_site.root_node
        default_scope = 'site'
      end

      unless query_params = params[:q]
        query_params = params.dup
        %w{controller action format}.each do |key|
          query_params.delete(key)
        end
      end

      if request.format != Mime::XML || params[:page] || params[:per_page]
        @search_per_page = params[:per_page] ? params[:per_page].to_i : 20
        @nodes = secure(Node) { Node.search_records(query_params, :node => @node, :default => {:scope => default_scope}, :page => params[:page], :per_page => @search_per_page) }
        @search_count = 100 # FIXME: @nodes ? @nodes.total_entries : 0
      else
        # XML without pagination
        @nodes = secure(Node) { Node.search_records(query_params, :node => @node, :default => {:scope => default_scope}) }
      end

      if @nodes.kind_of?(Node)
        @nodes = [@nodes]
      end
    end

    # Document data do not change session[:lang] and can point at cached content (no nee to redirect to AUTHENTICATED_PREFIX).
    def avoid_prefix_redirect
      @node.kind_of?(Document) && params[:format] == @node.ext
    end

    # Transform pseudo id into absolute paths (used after import)
    def parse_assets(nodes)
      nodes.each do |n|
        n.errors.instance_variable_get(:@errors).delete('asset')
        next unless n.errors.empty?
        attrs = {}

        n.parse_keys.each do |k|
          orig  = n.send(k)
          trans = n.parse_assets(orig, self, k)
          if trans && trans != orig
            attrs[k] = trans
          end
        end

        if attrs != {}
          attrs['v_status'] = n.version.status
          attrs['v_lang']   = n.version.lang
          n.update_attributes(attrs)
        end
      end
    end

    def check_can_drive
      raise ActiveRecord::RecordNotFound unless @node.can_drive?
    end

    def check_api_group
      return true if request.format != Mime::XML || visitor.api_authorized?

      render :xml => [{:message => 'Not in API group.'}].to_xml(:root => 'errors'), :status => 401
      false
    end
end

