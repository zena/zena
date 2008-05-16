class LinksController < ApplicationController
  before_filter :find_node
  before_filter :check_can_drive
  before_filter :find_link, :except => [:index, :create]
  
  def show
  end
  
  # Edit a link. Called from drive popup.
  def edit
    #puts "EDIT: #{@link['other_zip']}, #{@link['role']}, #{@link['status']}, #{@link['comment']}"
    respond_to do |format|
      format.html
      format.js { render :partial => 'form' }
    end
  end
  
  def update
    @link.update_attributes_with_transformations(params['link'])
    
    respond_to do |format|
      format.html do 
        if @node.errors.empty?
          redirect_to :action => 'show'
        else
          render :action => 'edit'
        end
      end
      format.js { render :action => 'show' }
    end
  end
  
  def create
    attrs = filter_attributes(params['link'])
    @node.add_link(attrs.delete(:role), attrs)
    @node.save
    
    respond_to do |format|
      format.js
    end
  end
  
  
  # Remove a link (drive popup).
  def remove_link
    unless @node.can_drive?
      @node.errors.add('base', 'you do not have the rights to do this')
    else
      @link_id = params[:link_id]
      @node.remove_link(@link_id)
      @node.save
    end
    respond_to do |format|
      format.js
    end
  end
  
  def destroy
    @node.remove_link(@link[:id])
    @node.save
    
    respond_to do |format|
      format.js
    end
  end
  
  protected
    def find_node
      @node = secure_drive!(Node) { Node.find_by_zip(params[:node_id]) }
    end
    
    def check_can_drive
      unless @node.can_drive?
        @node.errors.add('base', 'you do not have the rights to do this')
        return false
      end
    end
    
    def find_link
      @link = Link.find_through(@node, params[:id])
    end
    
    def filter_attributes(attributes)
      attrs = {}
      ['status', 'comment', 'role'].each do |k|
        attrs[k.to_sym] = attributes[k].blank? ? nil : attributes[k]
      end
      attrs[:id] = Node.translate_pseudo_id(attributes['other_zip'])
      attrs
    end
end