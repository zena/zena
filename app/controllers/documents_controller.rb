class DocumentsController < ApplicationController
  before_filter :find_node, :except => [ :file_form ]
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
  
  # create a document (upload)
  def create
    attrs = params['node']
    attrs[:klass] ||= 'Document'
    if attrs['c_file'].kind_of?(String)
      attrs['c_file'] = StringIO.new(attrs['c_file'])
      # StringIO
      (class << attrs['c_file']; self; end;).class_eval do
        define_method(:content_type) { '' }
        define_method(:original_filename) { attrs['name'] || 'file.txt' }
      end
    end
    @node = secure!(Document) { Document.create_node(attrs) }
    
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
  
  # TODO: test
  def file_form
    render :inline=>"<%= link_to_function(_('cancel'), \"['file', 'file_form'].each(Element.toggle);$('file_form').innerHTML = '';\")%><%= file_field 'node', 'c_file', :size=>15 %>"
    #respond_to do |format|
    #  format.html { render :inline=>"<%= link_to_function(_('cancel'), \"['file', 'file_form'].each(Element.toggle);$('file_form').innerHTML = '';\")%><%= file_field 'node', 'c_file', :size=>15 %>" }
    #end
  end
  
  # TODO: test
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

end
