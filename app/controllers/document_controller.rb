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
    if pdoc[:file] && pdoc[:file] !='' && pdoc[:file].content_type =~ /image/
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
    if params[:filename] =~ /([^-]+)-(.+)\.(.+)/
      name = "#{$1}.#{$3}"
      if IMAGEBUILDER_FORMAT[$2]
        format = $2
      else
        format = 'pv'
      end
    else
      name = params[:filename]
    end
    doc = secure(Document) { Document.version(params[:version_id]) }
    if doc.kind_of?(Image) && !ImageBuilder.dummy?
      data = doc.file(format)
    else
      data = doc.file
    end
    raise ActiveRecord::RecordNotFound unless doc.name == name
    send_data( data.read , :filename=>data.filename, :type=>data.content_type, :disposition=>'inline')
    cache_page if doc.public?
  rescue ActiveRecord::RecordNotFound
    page_not_found
  rescue IOError
    flash[:error] = trans "Some error occured: file missing."
  end

  # Used to clean list after adding stuff or when canceling
  def list
    @item = secure(Item) { Item.find(params[:parent_id])}
    render :partial=>'document/list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
