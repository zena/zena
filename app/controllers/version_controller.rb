class VersionController < ApplicationController
  layout :popup_layout
  
  #def show
  #  @node = secure(Node) { Node.version(params[:id]) }
  #  render_and_cache(:cache=>false)
  #rescue ActiveRecord::RecordNotFound
  #  page_not_found
  #end
  
  def edit
    if params[:id]
      @node = secure(Node) { Node.version(params[:id]) }
    elsif params[:node_id]
      @node = secure_write(Node) { Node.find(params[:id]) }
    end
    if params[:drive]
      if @node.redit
        flash[:notice] = trans "Version changed back to redaction."
      else
        flash[:error] = trans "Could not change version back to redaction."
      end    
      render :action=>'update'
    else
      if !@node.edit!
        flash[:error] = trans "Could not edit version."
        render_or_redir 404
      else
        # store the id used to preview when editing
        session[:preview_id] = params[:id]
        @edit = true
      end
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # preview when editing node
  def preview
    @preview_id = session[:preview_id]
    if params[:node]
      # redaction
      @node = secure_write(Node) { Node.find(params[:node][:id]) }
      @v_title   = params[:node][:v_title]
      @v_summary = params[:node][:v_summary]
      @v_text    = params[:node][:v_text]
    else
      # drive view
      @node = secure(Node) { Node.version(params[:id]) }
      @v_title   = @node.v_title
      @v_summary = @node.v_summary
      @v_text    = @node.v_text
      if @node.kind_of?(Image)
        # show image
        @v_text = @node.img_tag('full')
      end
    end
    if @node.kind_of?(TextDocument) && false
      @html = @v_text
    elsif @node.kind_of?(TextDocument)
      lang = @node.content_lang
      lang = lang ? " lang='#{lang}'" : ""
      @v_text = "<code#{lang} class='full'>#{@v_text}</code>"
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
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
  
  # Save a redaction with all it's content
  def save
    params[:node].delete(:preview_id)
    # use current context.
    @node = secure_write(Node) { Node.find(params[:node][:id]) }
    params[:node].delete(:file) if params[:node][:file] == ""
    parse_dates(params[:node])
    if @node.update_attributes(params[:node])
      session[:notice] = trans "Redaction saved."
    else
      flash[:error] = trans "Redaction not saved."
      render :action=>'edit' unless params[:action] == 'save_text'
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def save_text
    save
  end
  
  # Create a backup copy of the current redaction.
  def backup
    @node = secure_write(Node) { Node.version(params[:id]) }
    @node.backup
    if @node.errors.empty?
      flash[:notice] = trans "Backup created."
    else
      flash[:error] = trans "Could not create backup."
    end
  end
  
  def propose
    @node = secure(Node) { Node.version(params[:id]) }
    if @node.propose
      flash[:notice] = trans "Redaction proposed for publication."
      render_or_redir @request.env['HTTP_REFERER']
    else
      flash[:error] = trans "Could not propose redaction."
      render_or_redir 404
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def refuse
    @node = secure(Node) { Node.version(params[:id]) }
    
    if @node.refuse
      flash[:notice] = trans "Proposition refused."
      render_or_redir user_home_url
    else
      flash[:notice] = trans "Could not refuse proposition."
      render_or_redir @request.env['HTTP_REFERER']
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def publish
    @node = secure(Node) { Node.version(params[:id]) }
    if @node.publish
      flash[:notice] = "Redaction published."
      render_or_redir @request.env['HTTP_REFERER']
    else
      flash[:error] = "Could not publish: #{error_messages_for('node')}"
      render_or_redir 404
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def remove
    @node = secure(Node) { Node.version(params[:id]) }
    if @node.remove
      flash[:notice] = "Publication removed."
      render_or_redir @request.env['HTTP_REFERER']
    else
      flash[:error] = "Could not remove plublication."
      render_or_redir 404
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def unpublish
    @node = secure(Node) { Node.version(params[:id]) }
    if @node.unpublish
      flash[:notice] = "Publication removed."
      render_or_redir @request.env['HTTP_REFERER']
    else
      flash[:error] = "Could not remove plublication."
      render_or_redir 404
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  private
  
  def render_or_redir(url)
    if params[:drive]
      render :action=>'update'
    elsif url == 404
      page_not_found
    else
      redirect_to url
    end
  end
end