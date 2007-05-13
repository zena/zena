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
  layout :popup_layout,     :only   => [:edit ]
  
  def index
    @node = site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => 'index' }
      format.xml  { render :xml => @node.to_xml }
    end
  end
  
  def not_found
    @node = site.root_node
    respond_to do |format|
      format.html { render_and_cache :mode => 'not_found' }
      format.all { render :nothing => true }
    end
  end
  
  def search
    if params[:q] && params[:q] != ''
      match = Node.send(:sanitize_sql, ["MATCH (versions.title,versions.text,versions.summary) AGAINST (?)", params[:q]])
      query = {
        :select => "DISTINCT nodes.*, #{match} AS score",
        :join   => "INNER JOIN versions ON versions.node_id = nodes.id",
        :conditions => match,
        :order  => "score DESC" }
    elsif params[:id]
      query = {
        :conditions => ["parent_id = ? AND kpath LIKE 'NP%'",params[:id]],
        :order  => 'name ASC' }
    else
      # error
      raise Exception.new('bad arguments for search ("query" field missing)')
    end
    secure(Node) do
      @node_pages, @nodes = paginate :nodes, query.merge(:per_page => 10)
      @nodes # important: this is the 'secure' yield return, it is used to secure found nodes
    end
    respond_to do |format|
      # FIXME: html should render in a full page
      format.html { render :partial => 'results' }
      format.js  # this one renders the partial
    end
  end
  
  
  def show
    
    respond_to do |format|
      
      format.html do
        # FIXME: redirect if path is not correct.
        return redirect_to(zen_path(@node), :mode => params[:mode]) unless params[:path]
        render_and_cache 
      end
      
      format.xml  { render :xml => @node.to_xml }
      
      format.js   { @template_file = fullpath_from_template_url(params[:template_url]) } # zafu ajax
      
      format.all  do
        # Get document data (inline if possible)
        if params[:format] != @node.c_ext
          puts "redirect in show"
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
    unless params[:file] && params[:file].kind_of?(File)
      # FIXME: errors
      return
    end
    
    # TODO: FINISH
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
    elsif params[:drive]
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
      format.js   { @flash = flash }
      format.html { redirect_to node_url(@node[:zip]) }
    end
  end
  
  
  # create a link given the node id 'link[node_id]', the role 'link[role]' and the target id 'link[other_id]'. The target id
  # can also be a name
  # TODO: test multiple/single values
  def link
    attrs = zips_to_ids(params[:node])
    
    if params[:method] = :put
      # create/update links
      raise ActiveRecord::RecordNotFound unless @node.can_drive?
      
      box = params[:box]
      
      if attrs.keys.size == 0
        # empty => cleared
        if @node.respond_to?("#{box}_id=".to_sym)
          # unique
          @node.send("#{box}_id=".to_sym, nil)
        else
          # multiple
          @node.send("#{box.singularize}_ids=".to_sym, nil)
        end
        @node.save
      else
        @method = attrs.keys[0]
        unless @method =~ /^(.+)_id(s|)$/
          # bad method...
          processing_error 'unknown link role'
        else
          @node.send("#{@method}=".to_sym, attrs[@method])
          @node.save
        end
      end
    else
      # # add a link
      # @method = params[:link][:role]
      # other_zip = nil
      # if params[:link][:other_id] =~ /^\d+$/
      #   other_zip = params[:link][:other_id].to_i
      # else
      #   begin
      #     if other = secure(Node) { Node.find_by_name(params[:link][:other_id]) }
      #       other_zip = other[:zip]
      #     end
      #   end
      # end
      # if other_zip && @node.add_link(@method, other_zip) && @node.save
      #   Node.find_by_(other_zip).send(:after_all)
      # end
    end
  rescue ActiveRecord::RecordNotFound
    processing_error 'node not found'
  end
  
  
  # AJAX HELPER
  # TODO: test
  def attribute
    method = params[:attr].to_sym
    if [:v_text, :v_summary, :name, :path, :short_path].include?(method)
      if params[:node] =~ /^\d+$/
        @node = secure(Node) { Node.find_by_zip(params[:node]) }
      else
        @node = secure(Node) { Node.find_by_name(params[:node]) }
        raise ActiveRecord::RecordNotFound unless @node
      end
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
        if path.last =~ /([a-zA-Z\-]+)([0-9]*)(_[a-z]+|)(\..+|)/
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
          puts 'redirect in find_node'
          redirect_to zen_path(@node, :mode => params[:mode])
        end
      elsif params[:id]
        @node = secure(Node) { Node.find_by_zip(params[:id]) }
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

