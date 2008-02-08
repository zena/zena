class LinksController < ApplicationController
  before_filter :find_node
  
  
  # TODO: think this over
  # or node controller:
  # add_link, remove_link, node[other_role_ids] = ...
  # add     => add a new link                         (nodes/:node_zip/links?:relation_id=...&other_id=:other_zip)
  # update  => change current links for a relation    (nodes/:node_zip/links/:relation_id/update)
  # destroy => remove a link
  
  # POST /links
  # POST /links.xml
  def create
    relation = @node.relation_proxy(:id => params[:link][:relation_id])
    
    respond_to do |format|
      if @link.save
        flash[:notice] = 'Link was successfully created.'
        format.html { redirect_to link_url(@link) }
        format.xml  { render :xml => @link, :status => :created, :location => link_url(@link) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @link.errors }
      end
    end
  end

  # PUT /links/1
  # PUT /links/1.xml
  def update
    @link = Link.find(params[:id])

    respond_to do |format|
      if @link.update_attributes(params[:link])
        flash[:notice] = 'Link was successfully updated.'
        format.html { redirect_to link_url(@link) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @link.errors }
      end
    end
  end

  # DELETE /links/1
  # DELETE /links/1.xml
  def destroy
    @link = Link.find(params[:id])
    @link.destroy

    respond_to do |format|
      format.html { redirect_to links_url }
      format.xml  { head :ok }
    end
  end
  
  protected
    def find_node
      @node = secure_drive!(Node) { Node.find_by_zip(params[:node_id]) }
    end
end