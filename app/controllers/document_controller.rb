class DocumentController < ApplicationController
  layout 'popup'  
  helper MainHelper
  
  def new
    @node = secure_write(Node) { Node.find(params[:parent_id]) }
    @document = @node.new_child
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end

  def create
    pdoc = params[:document]
    pdoc.delete(:c_file) if pdoc[:c_file] == ""
    if Image.image_content_type?(pdoc[:c_file].content_type)
      @document = secure(Image) { Image.create(pdoc) }
    else
      @document = secure(Document) { Document.create(pdoc) }
    end
    if @document.new_record?
      render :action=>"new"
    end
    flash[:notice] = trans "upload succeeded"
  rescue ActiveRecord::RecordNotFound
    # user does not have write access to parent. This error should never happen (parent list is filtered)
    page_not_found
  end

  # Get document data (inline if possible)
  def data
    if params[:filename] =~ /(.+)-([^-]+)\.(.+)/
      name = $1
      format = $2
    elsif params[:filename] =~ /(.+)\.(.+)/
      name = $1
      format = nil
    else
      raise ActiveRecord::RecordNotFound
    end
    @document = secure(Document) { Document.version(params[:version_id]) }
    if @document.kind_of?(Image) && !ImageBuilder.dummy?
      data = @document.c_file(format)
    else
      data = @document.c_file
    end
    raise ActiveRecord::RecordNotFound unless @document.name == name
    send_data( data.read , :filename=>@document.c_filename, :type=>@document.c_content_type, :disposition=>'inline')
    
    # TODO: cache_document not tested yet. Also need sweepers !!
    if @document.public? && @document.v_status == Zena::Status[:pub] && perform_caching && caching_allowed
      cache_page
      if @document.kind_of?(Image) && format != nil
        # remove 'formatted' file
        @document.c_remove_image(format)
      end
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  rescue IOError
    flash[:error] = trans "Some error occured: file missing."
    page_not_found
  end

  # Used to clean list after adding stuff or when canceling
  def list
    @node = secure(Node) { Node.find(params[:parent_id])}
    render :partial=>'document/list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def file_form
    render :inline=>"<%= link_to_function(trans('cancel'), \"new Element.toggle('file', 'file_form');$('file_form').innerHTML = '';\")%><label for='document'>#{trans('change document')}</label><%= file_field 'node', 'c_file', :size=>nil %>"
  end
end
