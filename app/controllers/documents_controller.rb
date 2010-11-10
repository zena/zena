class DocumentsController < ApplicationController
  before_filter :find_node, :except => [ :get_uf, :upload_progress, :create ]

  skip_before_filter :set_lang,      :only => :upload_progress
  skip_before_filter :authorize,     :only => :upload_progress
  skip_before_filter :check_lang,    :only => :upload_progress
  skip_after_filter  :set_encoding,  :only => :upload_progress

  layout :popup_layout


  # add a new document to the current node
  def new
    @node = @parent.new_child(:class => Document)

    # Add Template role so that we can use the same object in forms which need the Template properties.
    @node.include_role Template

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
        @node.skin_id ||= current_site.root_node.skin_id

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

    responds_to_parent do # execute the redirect in the iframe's parent window
      render :update do |page|
        if @node.new_record?
          page.replace_html 'form_errors', error_messages_for(:node, :object => @node)
          page.call 'UploadProgress.setAsError'
        else
          page.call 'UploadProgress.setAsFinished'
          page.delay(1) do # allow the progress bar fade to complete
            page.redirect_to document_url(@node[:zip])
          end
        end
      end
    end
  end

  def upload_progress
    render_upload_progress
  end

  # TODO: test
  # display an upload field.
  def get_uf
    render_get_uf
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
      file, error = get_attachment
      attrs['file'] = file if file
      attrs['klass'] ||= 'Document'
      if error
        @node = secure!(Document) { Document.new }
        @node.attributes = attrs
        @node.errors.add('file', error)
      else
        @node = secure!(Document) { Document.create_node(attrs) }
      end
    end

end
