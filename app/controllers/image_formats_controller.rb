class ImageFormatsController < ApplicationController
  before_filter :check_is_admin
  before_filter :find_image_format, :except => [:index, :new, :create]
  before_filter :find_node
  layout :admin_layout

  def show
  end

  def edit
    respond_to do |format|
      format.html
      format.js { render :partial => 'form' }
    end
  end

  def index
    @image_format_pages, @image_formats = nil, nil
    @image_formats = ImageFormat.list
    @image_format  = ImageFormat.new
    respond_to do |format|
      format.html
    end
  end

  def create
    @image_format = ImageFormat.create(params[:image_format])
  end

  def update
    @image_format.update_attributes(params[:image_format])

    respond_to do |format|
      format.html do 
        if @image_format.errors.empty?
          redirect_to :action => 'show'
        else
          render :action => 'edit'
        end
      end
      format.js { render :action => 'show' }
    end
  end

  def destroy
    @image_format.destroy

    respond_to do |format|
      format.html do
        if @image_format.errors.empty?
          redirect_to :action => 'index' 
        else
          render :action => 'edit'
        end
      end
      format.js   do
        render(:partial => 'form') unless @image_format.errors.empty?
      end
      format.xml  { head :ok }
    end
  end

  protected
    def find_image_format
      if imf_id = params[:id]
        if imf_id =~ /[a-zA-Z]/
          # default format
          @image_format = ImageFormat.new_from_default(imf_id)
        else
          @image_format = secure!(ImageFormat) { ImageFormat.find(params[:id]) }
        end
      end
    end

    def find_node
      @node = visitor.contact
    end
end
