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
  before_filter :find_node, :except => [:index, :not_found, :search, :attribute]
  before_filter :check_can_drive, :only => [:add_link, :update_link, :remove_link]
  layout :popup_layout,     :only   => [:edit, :import]
  
  def index
    @node = current_site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => 'index' }
      format.xml  { render :xml => @node.to_xml }
    end
  end
  
  def not_found
    @node = current_site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => 'not_found' }
      format.all { render :nothing => true }
    end
  end
  
  def search
    do_search
    respond_to do |format|
      format.html { render_and_cache :mode => 'search' }
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
      format.js { @template_file = fullpath_from_template_url(params[:template_url])
        render :action => 'show' }
    end
  end
  
  def show
    
    respond_to do |format|
      
      format.html { render_and_cache }
      
      format.xml  { render :xml => @node.to_xml }
      
      format.js   { @template_file = fullpath_from_template_url(params[:template_url]) } # zafu ajax
      
      format.all  do
        # Get document data (inline if possible)
        if params[:format] != @node.c_ext
          return redirect_to(zen_path(@node), :mode => params[:mode])
        end
        
        if @node.kind_of?(Image) && !ImageBuilder.dummy?
          data = @node.c_file(params[:mode])
          content_path = @node.c_filepath(params[:mode])
          
        elsif @node.kind_of?(TextDocument)
          data = StringIO.new(@node.v_text)
          content_path = nil
          
        else
          data         = @node.c_file
          content_path = @node.c_filepath
        end
        raise ActiveRecord::RecordNotFound unless data
        
        send_data( data.read , :filename=>@node.c_filename, :type => @node.c_content_type, :disposition=>'inline')
        data.close
        cache_page(:content_path => content_path, :authenticated => @node.public?) # content_path is used to cache by creating a symlink
      end
    end
  end
  
  def create
    attrs = parse_dates
    @node = secure(Node) { Node.create_node(attrs) }
    
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
        # store the id used to preview versions
        session[:preview_id] = params[:preview_id] if params[:preview_id]
        @title_for_layout = @node.rootpath
      end
      format.js do
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
    @node = secure_write(Node) { Node.version(params[:id]) }
    @node.backup
    if @node.errors.empty?
      flash[:notice] = _("Backup created.")
    else
      flash[:error] = _("Could not create backup.")
    end
  end
  
  # import sub-nodes from a file
  def import
    @nodes = secure(Node) { Node.create_nodes_from_folder(:archive => params[:archive], :parent => @node) }
  end
  
  # add/update links to another node
  def update_link
    # update relation
    attrs = clean_attributes(params['link'])
    @node.update_attributes(attrs)
    respond_to do |format|
      format.js { render :action => 'link'}
    end
  end
  
  def add_link
    if relation = @node.relation_proxy(params['link']['role'])
      attrs = clean_attributes(params['link'])
      if relation.unique?
        # replace link
        @node.update_attributes("#{attrs['role']}_id" => attrs['other_id'])
      else
        @node.add_link(attrs['role'], attrs['other_id'])
        @node.save
      end
    else
      @node.errors.add('base', 'invalid role')
    end
    respond_to do |format|
      format.js { render :action => 'link'}
    end
  end
  
  # remove a link
  def remove_link
    unless @node.can_drive?
      @node.errors.add('base', 'you do not have the rights to do this')
    else
      @link_id = params[:link_id]
      @node.remove_link(@link_id)
      @node.save
    end
    respond_to do |format|
      format.js
    end
  end
  
  def update
    attrs = clean_attributes
    attrs.delete(:klass)
    attrs.delete(:c_file) if attrs[:c_file] == ""
    
    if params[:template_url]
      # edit from inline form in zafu
      @update = 'zafu'
    elsif params[:identifier]
      @update = 'attribute'
    elsif ['parent', 'dates', 'groups', 'links'].include? params[:drive]
      # drive editing
      @update = params[:drive]
    else
      @update = 'edit'
    end
    
    @node.update_attributes(attrs)
    if @node.errors.empty?
      flash.now[:notice] = _('node updated')
    else
      flash.now[:error]  = _('could not update')
    end
    
    respond_to do |format|
      format.html do
        if params[:edit] == 'popup'
          redirect_to edit_version_url(:node_id => @node[:zip], :id=>(@node.v_number || 0)) 
        else
          redirect_to zen_path(@node)
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
      node_id = secure(Node) { Node.translate_pseudo_id(params[:node])}
      @node = secure(Node) { Node.find(node_id) }
      raise ActiveRecord::RecordNotFound unless @node
      
      if method == :path || method == :short_path
        path = @node.rootpath
        if method == :short_path && path.size > 2
          path = ['..'] + path[-2..-1]
        end
        render :inline=> path.join('/')
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
      child = secure(Node) { Node.find_by_zip(zip) }
      child.position = idx
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
  
  
  protected
    
    def find_node
      if path = params[:path]
        if path.last =~ /([a-zA-Z\-]*)([0-9]*)(_[a-z]+|)(\..+|)/
          name   = $1
          zip    = $2
          params[:mode  ] = $3 == '' ? nil : $3[1..-1]
          params[:format] = $4 == '' ? ''  : $4[1..-1]
          if zip != ""
            basepath = path[0..-2].join('/')
            @node = secure(Node) { Node.find_by_zip(zip) }
          else
            basepath = (path[0..-2] + [name]).join('/')
            @node = secure(Node) { Node.find_by_path(basepath) }
          end
        end
        if params[:format] == '' || (params[:format] == 'html' && ( (zip != '' && @node.custom_base) || basepath != @node.basepath(true)))
          redirect_to zen_path(@node, :mode => params[:mode])
        elsif params[:mode] =~ /_edit/ && !@node.can_write?
          redirect_to zen_path(@node)
        end
      elsif params[:id]
        @node = secure(Node) { Node.find_by_zip(params[:id]) }
      end
      @title_for_layout = @node.rootpath if @node
    end

    def check_can_drive
      if !@node.can_drive?
        @node.errors.add('base', 'you do not have the rights to do this')
      end
    end
    
    def do_search
      @node = current_site.root_node
      query = Node.match_query(params[:q], :node => @node)
      secure(Node) do
        @node_pages, @nodes = paginate :nodes, query.merge(:per_page => 10)
        @nodes # important: this is the 'secure' yield return, it is used to secure found nodes
      end
    end

=begin
  
  # test to here
  def test
    if request.get?
      @node = secure(Page) { Page.find(params[:id]) }
    else
      @node = secure(Page) { Page.find(params[:id]) }
      params[:node][:tag_ids] = [] unless params[:node][:tag_ids]
      @node.update_attributes(params[:node])
    end
  end
  

  
  def not_found
    # render 'node/not_found' with popup layout
  end
  
  private
  
  def popup_page_not_found
    redirect_to :controller => 'node', :action=>'not_found'
  end
  # TODO: change to ?
  #if @node.type != params[:node][:type]
  #  @node = @node.change_to(eval "#{params[:node][:type]}")
  #end
=end
end

