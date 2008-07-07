class VersionsController < ApplicationController
  layout :popup_layout, :except => [:preview, :diff]
  before_filter :find_node
  
  # Display a specific version of a node
  # TODO: this controller is nearly the same as NodesController#show, except caching is disabled. Any idea to DRY this ?
  def show
    respond_to do |format|
      
      format.html { render_and_cache(:cache=>false) }
      
      format.xml  { render :xml => @node.to_xml }
      
      format.js # show.rjs
      
      format.all  do
        # Get document data (inline if possible)
        if params[:format] != @node.c_ext
          return redirect_to(params.merge(:format => @node.c_ext))
        end
        
        if @node.kind_of?(Image) && !ImageBuilder.dummy?
          img_format = Iformat[params[:mode]]
          data = @node.c_file(img_format)
          content_path = @node.c_filepath(img_format)
          disposition  = 'inline'
          
        elsif @node.kind_of?(TextDocument)
          data = StringIO.new(@node.v_text)
          content_path = nil
          disposition  = 'attachment'
          
        else
          data         = @node.c_file
          content_path = @node.c_filepath
          disposition  = 'inline'
        end
        raise ActiveRecord::RecordNotFound unless data
          
        send_data( data.read , :filename=>@node.filename, :type=>@node.c_content_type, :disposition=>disposition)
        data.close
        
        # should we cache the page ?
        # cache_page(:content_path => content_path) # content_path is used to cache by creating a symlink
      end
    end
  end
  
  def edit
    if params[:drive]
      if @node.redit
        flash[:notice] = _("Version changed back to redaction.")
      else
        flash[:error] = _("Could not change version back to redaction.")
      end    
      render :action=>'update'
    else
      if !@node.edit!
        flash[:error] = _("Could not edit version.")
        render_or_redir 404
      else
        @title_for_layout = @node.rootpath
        if @node.kind_of?(TextDocument)
          if params['parse_assets']
            @node.parse_assets!(self)
          elsif @node.kind_of?(TextDocument) && params['unparse_assets']
            @node.unparse_assets
          end
        end
        @edit = true
      end
    end
  end
  
  # TODO: test/improve or remove (experiments)
  def diff
    # drive view
    @node = secure!(Node) { Node.find(params[:id]) }
    @from = @node.version(params[:from])
    @to   = @node.version(params[:to])
    
  end
  
  # preview when editing node
  def preview
    if @key = (params['key'] || params['amp;key'])
      @value = params[:content]
      if @node.kind_of?(TextDocument) && @key == 'v_text'
        l = @node.content_lang
        @value = "<code#{l ? " lang='#{l}'" : ''} class=\'full\'>#{@value}</code>"
      end
      # redaction
    elsif @node.kind_of?(Image)
      # view image version
      # TODO: how to show the image data of a version ? 'nodes/3/versions/4.jpg' ?
      @node.version.text = "<img src='#{url_for(:controller=>'versions', :node_id=>@node[:zip], :id=>@node.v_number, :format=>@node.c_ext)}'/>"
    elsif @node.kind_of?(TextDocument)
      lang = @node.content_lang
      lang = lang ? " lang='#{lang}'" : ""
      @node.version.text = "<code#{lang} class='full'>#{@v_text}</code>"
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  # This is a helpers used when creating the css for the site. They have no link with the database
  def css_preview
    file = params[:css].gsub('..','')
    path = File.join(RAILS_ROOT, 'public', 'stylesheets', file)
    if File.exists?(path)
      if session[:css] && session[:css] == File.stat(path).mtime
        render :nothing=>true
      else
        session[:css] = File.stat(path).mtime
        @css = File.read(path)
      end
    else
      render :nothing=>true
    end
  end
  
  def propose
    if @node.propose
      flash[:notice] = _("Redaction proposed for publication.")
    else
      flash[:error] = _("Could not propose redaction.")
    end
    do_rendering
  end
  
  def refuse
    if @node.refuse
      flash[:notice] = _("Proposition refused.")
      @redirect_url = @node.can_read? ? request.env['HTTP_REFERER'] : user_path(visitor)
    else
      flash[:notice] = _("Could not refuse proposition.")
    end
    do_rendering
  end
  
  def publish
    if @node.publish
      flash[:notice] = "Redaction published."
    else
      flash[:error] = "Could not publish: #{error_messages_for(@node)}"
    end
    do_rendering
  end
  
  def remove
    if @node.remove
      flash[:notice] = "Publication removed."
    else
      flash[:error] = "Could not remove plublication."
    end
    do_rendering
  end
  
  def redit
    if @node.redit
      flash[:notice] = "Rolled back to redaction."
    else
      flash[:error] = "Could not rollback: #{error_messages_for(@node)}"
    end
    do_rendering
  end
  
  # TODO: test
  def unpublish
    if @node.unpublish
      flash[:notice] = "Publication removed."
    else
      flash[:error] = "Could not remove publication."
    end
    do_rendering
  end
  
  # TODO: test
  def destroy_version
    if @node.destroy_version
      flash[:notice] = "Version destroyed."
    else
      flash[:error] = "Could not destroy version."
    end
    do_rendering
  end
  
  
  protected
    def find_node
      @node = secure!(Node) { Node.find_by_zip(params[:node_id]) }
      if params[:id].to_i != 0
        # try to set current version from version number
        redirect_to :id => @node.v_number unless @node.version(params[:id])
      end
    end
    
    def do_rendering
      respond_to do |format|
        format.html { redirect_to @redirect_url || request.env['HTTP_REFERER'] }
        # js = call from 'drive' popup
        format.js   { render :action => 'update' }
      end
    end
end