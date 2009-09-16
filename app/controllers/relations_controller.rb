class RelationsController < ApplicationController
  before_filter :visitor_node
  before_filter :find_relation, :except => [:index, :create, :new]
  before_filter :check_is_admin
  layout :admin_layout

  def index
    @relation  = Relation.new

    @relation_pages, @relations = nil, nil
    secure!(Relation) do
      @relation_pages, @relations = paginate :relations, :per_page => 20, :order => 'source_role'
    end
    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @relations }
    end
  end

  def show
    respond_to do |format|
      format.html # show.erb
      format.xml  { render :xml => @relation }
      format.js
    end
  end

  def new
    @relation = Relation.new

    respond_to do |format|
      format.html # new.erb
      format.xml  { render :xml => @relation }
    end
  end

  # TODO: test
  def edit
    respond_to do |format|
      format.html { render :partial => 'relations/form' }
      format.js   { render :partial => 'relations/form', :layout => false }
    end
  end

  def create
    @relation = Relation.new(params[:relation])

    respond_to do |format|
      if @relation.save
        flash[:notice] = 'Relation was successfully created.'
        format.html { redirect_to relation_url(@relation) }
        format.js
        format.xml  { render :xml => @relation, :status => :created, :location => relation_url(@relation) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @relation.errors }
      end
    end
  end

  def update
    @relation = Relation.find(params[:id])

    respond_to do |format|
      if @relation.update_attributes(params[:relation])
        flash[:notice] = 'Relation was successfully updated.'
        format.html { redirect_to relation_url(@relation) }
        format.js
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js
        format.xml  { render :xml => @relation.errors }
      end
    end
  end

  def destroy
    @relation.destroy

    respond_to do |format|
      format.html { redirect_to relations_url }
      format.xml  { head :ok }
      format.js
    end
  end

  protected
    def visitor_node
      @node = visitor.contact
    end

    def find_relation
      @relation = secure!(Relation) { Relation.find(params[:id])}
    end
end
