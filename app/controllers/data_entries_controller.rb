class DataEntriesController < ApplicationController
  before_filter :find_data_entry, :except => [:create]
  before_filter :check_can_edit
  layout :admin_layout

  def new
    # TODO
  end

  def create
    attrs = params['data_entry']
    @data_entry = secure(Node) { DataEntry.create_data_entry(attrs) }
    
    respond_to do |format|
      if @data_entry.errors.empty?
        flash[:notice] = _('Data entry was successfully created.')
        format.html { redirect_to data_entry_url(@node) }
        format.js
        format.xml  { head :created, :location => data_entry_url(@node) }
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
  
  def edit
    respond_to do |format|
      format.js do
        # zafu edit
        render :template => 'data_entries/edit.rjs' # FIXME: this should not be needed. Rails bug ?
      end
    end
  end
  
  def create
    @data_entry = DataEntry.create(params[:data_entry])
  end

  def update
    @data_entry.update_attributes_with_transformation(params[:data_entry])
  
    respond_to do |format|
      format.html # TODO
      format.js { render :action=>'show' }
    end
  end
  
  private
    def find_data_entry
      @data_entry = DataEntry.find_by_id_and_site_id(params[:id], visitor.site[:id])    
      return true
    end
    
    def check_can_edit
      if @data_entry
        @data_entry.can_write?
      else
        begin
          secure_write(Node) { Node.find_by_zip(params[:node_a_id]) }
        rescue
          return false
        end
      end
      return true
    end
end
