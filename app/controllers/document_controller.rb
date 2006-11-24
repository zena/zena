class DocumentController < ApplicationController
  layout 'popup'  
  helper MainHelper
  
  def new
    @item = secure_write(Item) { Item.find(params[:parent_id]) }
    @document = @item.new_child
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end

  def create
    pdoc = params[:document]
    pdoc.delete(:file) if pdoc[:file] == ""
    if Image.image_content_type?(pdoc[:file].content_type)
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
      if IMAGEBUILDER_FORMAT[$2]
        format = $2
      else
        format = 'pv'
      end
    elsif params[:filename] =~ /(.+)\.(.+)/
      name = $1
      format = nil
    else
      raise ActiveRecord::RecordNotFound
    end
    @document = secure(Document) { Document.version(params[:version_id]) }
    if @document.kind_of?(Image) && !ImageBuilder.dummy?
      data = @document.file(format)
    else
      data = @document.file
    end
    raise ActiveRecord::RecordNotFound unless @document.name == name
    send_data( data.read , :filename=>data.filename, :type=>data.content_type, :disposition=>'inline')
    
    # TODO: cache_document not tested yet. Also need sweepers !!
    if @document.public? && @document.v_status == Zena::Status[:pub] && perform_caching && caching_allowed
      cache_page
      if data.kind_of?(ImageFile) && data.format != nil
        # remove 'formatted' file
        data.remove_image_file
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
    @item = secure(Item) { Item.find(params[:parent_id])}
    render :partial=>'document/list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
