class VersionController < ApplicationController
  layout 'popup'
  helper MainHelper
  
  def show
    @node = secure(Node) { Node.version(params[:id]) }
    render_and_cache(:cache=>false)
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def edit
    if params[:id]
      @node = secure(Node) { Node.version(params[:id]) }
    elsif params[:node_id]
      @node = secure_write(Node) { Node.find(params[:id]) }
    end
    if !@node.edit!
      page_not_found
    else
      # store the id used to preview when editing
      session[:preview_id] = params[:id]
      render_form
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
  
  
  def save
    params[:node].delete(:preview_id)
    # use current context.
    @node = secure_write(Node) { Node.find(params[:node][:id]) }
    params[:node].delete(:file) if params[:node][:file] == ""
    parse_dates(params[:node])
    if @node.update_attributes(params[:node])
      session[:notice] = trans "Redaction saved."
    else
      flash[:error] = trans "Redaction could not be saved"
      render_form
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def save_text
    @node = secure_write(Node) { Node.find(params[:id]) }
    @node.update_attributes(:v_text=>params[:node][:v_text], :v_summary=>params[:node][:v_summary], :v_title=>params[:node][:v_title])
  end
  
  def propose
    node = secure(Node) { Node.version(params[:id]) }
    if node.propose
      flash[:notice] = trans "Redaction proposed for publication."
      redirect_to @request.env['HTTP_REFERER'] #:action=> 'show', :id => node.v_id
    else
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def refuse
    node = secure(Node) { Node.version(params[:id]) }
    
    if node.refuse
      flash[:notice] = trans "Proposition refused."
      redirect_to user_home_url
    else
      flash[:notice] = trans "Could not refuse proposition."
      redirect_to @request.env['HTTP_REFERER']
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def publish
    node = secure(Node) { Node.version(params[:id]) }
    if node.publish
      flash[:notice] = "Redaction published."
      redirect_to @request.env['HTTP_REFERER'] #redirect_to :action => 'show', :id => node.v_id
    else
      flash[:error] = "Could not publish."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def remove
    node = secure(Node) { Node.version(params[:id]) }
    if node.remove
      flash[:notice] = "Publication removed."
      redirect_to @request.env['HTTP_REFERER'] #:action => 'show', :id => node.v_id
    else
      flash[:error] = "Could not remove plublication."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def unpublish
    node = secure(Node) { Node.version(params[:id]) }
    if node.unpublish
      flash[:notice] = "Publication removed."
      redirect_to @request.env['HTTP_REFERER'] #:action => 'show', :id => node.v_id
    else
      flash[:error] = "Could not remove plublication."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
end