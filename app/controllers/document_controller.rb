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
  rescue ActiveRecord::RecordNotFound
    # user does not have write access to parent. This error should never happen (parent list is filtered)
    page_not_found
  end

  # Show scaled images
  def img
    if params[:img_name] =~ /([^-]+)-(.+)\.(.*)/
      # only valid formats can be generated
      name = $1
      if $image_format[$2]
        format = $2
      else
        format = 'pv'
      end
    else
      raise ActiveRecord::RecordNotFound
    end
    doc = secure(Image) { Image.version(params[:version_id]) }
    img = doc.data(format)
    raise ActiveRecord::RecordNotFound unless img.name == params[:img_name]
    send_data( img.read , :filename=>img.name, :type=>img.content_type, :disposition=>'inline')
    #cache_page if doc.public?
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end

  def doc_type
    if params[:doc_name] =~ /([a-z]*)(-?)([a-z]+)\.png$/
      name = $1
      # only valid formats can be generated
      if $image_format[$3]
        format = $3
      else
        format = nil
      end
      # TODO : find a better way to call 'pict' from outside Version
      v = Version.new
      send_data( v.read(format,"#{RAILS_ROOT}/doc_type/#{params[:doc_name]}", "#{RAILS_ROOT}/doc_type/#{name}.png") , 
      :filename=>params[:doc_name], :type=>"image/png", :disposition=>'inline')

      # always cache icon pictures
      cache_page
    else
      # bad doc_type name
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing => true
  end

  # Used to clean list after adding stuff or when canceling
  def list
    @item = secure(Item) { Item.find(params[:parent_id])}
    render :partial=>'document/list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
