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
=begin  OLD LINK CONTROLLER
class LinkController < ApplicationController
  
  # create a link given the node id 'link[node_id]', the role 'link[role]' and the target id 'link[other_id]'. The target id
  # can also be a name
  # TODO: test multiple/single values
  def create
    @node = secure_drive!(Node) { Node.find(params[:link][:node_id]) }
    if params[:node]
      # update node links with list
      box = params[:node][:box]
      params[:node].delete(:box)
      if params[:node].keys.size == 0
        # empty => cleared
        if @node.respond_to?("#{box}_id=".to_sym)
          # unique
          @node.send("#{box}_id=".to_sym, nil)
        else
          # multiple
          @node.send("#{box.singularize}_ids=".to_sym, nil)
        end
        @node.save
      else
        @method = params[:node].keys[0]
        unless @method =~ /^(.+)_id(s|)$/
          # bad method...
          processing_error'unknown link role'
        else
          @node.send("#{@method}=".to_sym, params[:node][@method])
          @node.save
        end
      end
    else
      # add a link
      @method = params[:link][:role]
      other_id = nil
      if params[:link][:other_id] =~ /^\d+$/
        other_id = params[:link][:other_id].to_i
      else
        begin
          if other = secure!(Node) { Node.find_by_name(params[:link][:other_id]) }
            other_id = other[:id]
          end
        end
      end
      if other_id && @node.add_link(@method, other_id) && @node.save
        Node.find(other_id).send(:after_all)
      end
    end
  rescue ActiveRecord::RecordNotFound
    processing_error 'node not found'
  end
  
  def select_for
    @node = secure!(Node) { Node.find(params[:id]) }
    @node.class.roles.each do |r|
      if r[:method].to_s == params[:role]
        @role = r
        break
      end
    end
    if @role
      if @role[:collector]
        render :inline=>"<%= select_id('link', 'other_id', :show=>:short_path) %>"
      else
        render :inline=>"<%= hidden_field('node','box', :value=>'#{@role[:method]}') %><%= link_box 'node', '#{@role[:method]}', :title=>nil, :as_unique=>#{@role[:as_unique].inspect} %>"
      end
    else
      render :inline=>_('role not valid')
    end
  end
  
  # remove a link given the link id 'id' and the node id 'node_id'
  def remove
    @node = secure_drive!(Node) { Node.find(params[:node_id]) }
    @link_id = params[:id]
    @node.remove_link(@link_id) && @node.save
  rescue ActiveRecord::RecordNotFound
    processing_error'node not found'
  end
end
=end