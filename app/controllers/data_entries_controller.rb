class DataEntriesController < ApplicationController
  before_filter :find_data_entry, :except => [:create]
  before_filter :check_can_edit
  layout :admin_layout

  def show
  end
  
  def new
    # TODO
  end

  def create
    @data_entry = secure!(Node) { DataEntry.create_data_entry(params['data_entry']) }
    
    respond_to do |format|
      if @data_entry.errors.empty?
        flash[:notice] = _('Data entry was successfully created.')
        format.html { redirect_to data_entry_url(@data_entry) }
        format.js
        format.xml  { head :created, :location => data_entry_url(@data_entry) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @data_entry.errors.to_xml }
      end
    end
  end

  def zafu
    respond_to do |format|
      format.js { @template_file = fullpath_from_template_url(params[:template_url])
        render :action => 'show' }
    end
  end
  
  # modifications of the node itself (dates, groups, revert editions, etc)
  def edit
    respond_to do |format|
      format.js do
        # zafu edit
        render :template => 'data_entries/edit.rjs' # FIXME: this should not be needed. Rails bug ?
      end
    end
  end

  def update
    @data_entry.update_attributes_with_transformation(params[:data_entry])
  
    respond_to do |format|
      format.html # TODO
      format.js
    end
  end
  
  def destroy
    @data_entry.destroy

    respond_to do |format|
      format.html { redirect_to zen_path(@node) }
      format.js
      format.xml  { head :ok }
    end
  end
  
  private
    def find_data_entry
      return false unless @data_entry = secure(DataEntry) { DataEntry.find_by_id(params[:id]) }
      @node = @data_entry.node_a
    end
    
    def check_can_edit
      if @data_entry
        @data_entry.can_write?
      else
        unless @node = secure_write(Node) { Node.find_by_zip(params['data_entry']['node_a_id']) }
          return false
        end
      end
      return true
    end
end
