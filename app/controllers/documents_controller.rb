class DocumentsController < ApplicationController
  session :off, :only => :upload_progress
  before_filter :find_node, :except => [ :file_form, :upload_progress ]
  
  skip_before_filter :set_lang,      :only => :upload_progress
  skip_before_filter :authorize,     :only => :upload_progress
  skip_before_filter :check_lang,    :only => :upload_progress
  skip_after_filter  :set_encoding,  :only => :upload_progress
  
  layout :popup_layout
  
  
  # add a new document to the current node
  def new
    @node = @parent.new_child(:class => Document)
    
    respond_to do |format|
      format.html
    end
  end
  
  # show the result of an upload
  def show
    respond_to do |format|
      format.html
    end
  end
  
  # create a document (direct upload). Used when javascript is disabled.
  def create
    create_document
    
    respond_to do |format|
      if @node.new_record?
        flash[:error] = _("Upload failed.")
        format.html { render :action => 'new'}
      else
        flash[:notice] = _("Upload succeeded.")
        format.html { redirect_to document_url(@node[:zip]) }
      end
    end
  end
  
  # Create a document with upload progression (upload in mongrel)
  def upload
    create_document
    
    responds_to_parent do # execute the redirect in the main window
      render :update do |page|
        page.call "UploadProgress.setAsFinished"
        page.delay(1) do # allow the progress bar fade to complete
          page.redirect_to document_url(@node[:zip])
        end
      end  
    end
  end
  
  def upload_progress
    render :update do |page|
      @status = Mongrel::Uploads.check(params[:upload_id])
      page.upload_progress.update(@status[:size], @status[:received]) if @status
    end
  end
  
  # TODO: test
  # display an upload field.
  def file_form
    render :inline=>"<%= link_to_function(_('cancel'), \"['file', 'file_form'].each(Element.toggle);$('file_form').innerHTML = '';\")%><%= file_field 'node', 'c_file', :size=>15 %>"
    #respond_to do |format|
    #  format.html { render :inline=>"<%= link_to_function(_('cancel'), \"['file', 'file_form'].each(Element.toggle);$('file_form').innerHTML = '';\")%><%= file_field 'node', 'c_file', :size=>15 %>" }
    #end
  end
  
  # TODO: test
  # display the image editor
  def crop_form
    respond_to do |format|
      format.js
    end
  end
  
  protected
    def find_node
      
      if params[:id]
        @node = secure!(Document) { Document.find_by_zip(params[:id]) }
      elsif parent_zip = (params[:node] || params)[:parent_id]
        @parent = secure!(Node) { Node.find_by_zip(parent_zip)}
      else
        # TODO: a better error message
        raise ActiveRecord::RecordNotFound
      end
    end
    
    def create_document
      attrs = params['node']
      attrs['c_file'] = params['data'] if params['data'] # upload-progress needs 'data' as name
      attrs[:klass] ||= 'Document'
      if attrs['c_file'].kind_of?(String)
        attrs['c_file'] = StringIO.new(attrs['c_file'])
        # StringIO
        if attrs['name'] =~ /^.*\.(\w+)$/ && types = EXT_TO_TYPE[$1]
          content_type = types[0]
        else
          content_type = ''
        end
        (class << attrs['c_file']; self; end;).class_eval do
          define_method(:content_type) { content_type }
          define_method(:original_filename) { attrs['name'] || 'file.txt' }
        end
      end
      @node = secure!(Document) { Document.create_node(attrs) }
    end

end
