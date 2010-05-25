class IformatsController < ApplicationController
  before_filter :check_is_admin
  before_filter :find_iformat, :except => [:index, :new, :create]
  before_filter :visitor_node
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
    @iformat_pages, @iformats = nil, nil
    @iformats = Iformat.list
    @iformat  = Iformat.new
    respond_to do |format|
      format.html
    end
  end

  def create
    @iformat = Iformat.create(params[:iformat])
  end

  def update
    @iformat.update_attributes(params[:iformat])

    respond_to do |format|
      format.html do
        if @iformat.errors.empty?
          redirect_to :action => 'show'
        else
          render :action => 'edit'
        end
      end
      format.js { render :action => 'show' }
    end
  end

  def destroy
    @iformat.destroy

    respond_to do |format|
      format.html do
        if @iformat.errors.empty?
          redirect_to :action => 'index'
        else
          render :action => 'edit'
        end
      end
      format.js   do
        render(:partial => 'form') unless @iformat.errors.empty?
      end
      format.xml  { head :ok }
    end
  end

  protected
    def find_iformat
      if imf_id = params[:id]
        if imf_id =~ /[a-zA-Z]/
          # default format
          @iformat = Iformat.new_from_default(imf_id)
        else
          @iformat = secure!(Iformat) { Iformat.find(params[:id]) }
        end
      end
    end
end
