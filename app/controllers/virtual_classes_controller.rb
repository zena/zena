class VirtualClassesController < ApplicationController
  before_filter :find_virtual_class, :except => [
    :index, :create, :new, :import, :import_prepare, :export
  ]
  before_filter :visitor_node
  before_filter :check_is_admin
  layout :admin_layout

  def index
    secure(::Role) do
      @virtual_classes = ::Role.paginate(:all, :order => 'kpath', :per_page => 200, :page => params[:page])
    end

    if last = @virtual_classes.last
      last_kpath = last.kpath
      Node.native_classes.each do |kpath, klass|
        if kpath < last_kpath
          @virtual_classes << klass
        end
      end
    else
      Node.native_classes.each do |kpath, klass|
        @virtual_classes << klass
      end
    end

    @virtual_classes.sort! do |a, b|
      if a.kpath == b.kpath
        # Order VirtualClass first
        b_type = b.kind_of?(::Role) ? b.class.to_s : 'V' # sort real classes like VirtualClass
        a_type = a.kind_of?(::Role) ? a.class.to_s : 'V'

        b_type <=> a_type
      else
        a.kpath <=> b.kpath
      end
    end

    @virtual_class  = VirtualClass.new('')

    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @virtual_classes }
    end
  end

  def export
    send_data(clean_yaml(::Role.export), :filename=>"roles.yml", :type => 'text/yaml')
  end

  def import_prepare
    attachment = params[:attachment]
    if attachment.nil?
      flass[:error] = _("Upload failure: no definitions.")
      redirect_to :action => :index
    else
      @yaml = attachment.read rescue nil
      data = YAML.load(@yaml) rescue nil
      if data.nil?
        flash.now[:error] = "Could not parse yaml document"
        redirect_to :action => :index
      else
        @yaml.gsub!(/\A---\s*\n/, "--- \n")
        current = current_compared_to(data)
        a = clean_yaml(current).gsub('{}', '')
        #a = Zena::CodeSyntax.new(a, 'yaml').to_html
        b = @yaml
        #b = Zena::CodeSyntax.new(b, 'yaml').to_html
        @diff = Differ.diff_by_line(b, a).format_as(:html)

        # UGLY HACK to not escape <ins> and <del>
        @diff.gsub!(/<((ins|del)[^>]*)>/, '[yaml_diff[\1]]')
        @diff.gsub!(/<\/(ins|del)>/, '[yaml_diff[/\1]]')
        @diff = Zena::CodeSyntax.new(@diff, 'yaml').to_html
        @diff.gsub!(/\[yaml_diff\[([^\]]+)\]\]/) do
          "<#{$1.gsub('&quot;', '"')}>"
        end
      end
    end
  end

  def import
    data = YAML.load(params[:roles]) rescue nil
    if data.nil?
      flash.now[:error] = _("Could not parse yaml document")
      redirect_to :action => :index
    else
      @roles_backup    = clean_yaml(::Role.export)
      @virtual_classes = ::Role.import(data)
      class << @virtual_classes
        def total_pages; 1 end
      end
      @virtual_class   = VirtualClass.new('')
      respond_to do |format|
        format.html { render :action => 'index' }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    r = e.record
    if r.respond_to?(:name)
      flash[:error] = "#{r.class} '#{r.name}' #{e.message}"
    else
      flash[:error] = "#{r.class} '#{r.inspect}' #{e.message}"
    end
    redirect_to :action => :index
  rescue Exception => e
    flash.now[:error] = e.message
    redirect_to :action => :index
  end

  def show
    respond_to do |format|
      format.html # show.erb
      format.js
      format.xml  { render :xml => @virtual_class }
    end
  end

  def new
    @virtual_class = VirtualClass.new('')

    respond_to do |format|
      format.html # new.erb
      format.xml  { render :xml => @virtual_class }
    end
  end

  # TODO: test
  def edit
    respond_to do |format|
      format.html { render :partial => 'virtual_classes/form' }
      format.js   { render :partial => 'virtual_classes/form', :layout => false }
    end
  end

  def create
    type = params[:virtual_class].delete(:type)
    if type == 'Role'
      @virtual_class = ::Role.new(params[:virtual_class])
    else
      @virtual_class = VirtualClass.new(params[:virtual_class])
    end

    respond_to do |format|
      if @virtual_class.save
        flash.now[:notice] = _('VirtualClass was successfully created.')
        format.html { redirect_to virtual_class_url(@virtual_class) }
        format.js
        format.xml  { render :xml => @virtual_class, :status => :created, :location => virtual_class_url(@virtual_class) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @virtual_class.errors }
      end
    end
  end

  def update
    respond_to do |format|
      if @virtual_class.update_attributes(params[:virtual_class])
        flash.now[:notice] = _('VirtualClass was successfully updated.')
        format.html { redirect_to virtual_class_url(@virtual_class) }
        format.js
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js
        format.xml  { render :xml => @virtual_class.errors }
      end
    end
  end

  def destroy
    @virtual_class.destroy

    respond_to do |format|
      format.html { redirect_to virtual_classes_url }
      format.xml  { head :ok }
      format.js
    end
  end

  protected
    def find_virtual_class
      @virtual_class = secure!(VirtualClass) { ::Role.find(params[:id])}
    end

    def clean_yaml(export)
      # We use an OrderedHash so that using diff is more consistent.
      export.to_yaml.gsub(/: *!map:Zafu::OrderedHash */, ':')
    end

    def get_roles(definitions, res = {})
      definitions.each do |name, definition|
        next unless name =~ /\A[A-Z]/
        res[name] = definition
        get_roles(definition, res)
      end
      res
    end
    # When comparing current data with imported data, ignore untouched
    # classes/definitions.
    def current_compared_to(definitions)
      current = ::Role.export
      roles   = get_roles(definitions)
      filter_keys(current, definitions, roles)
      current
    end

    def filter_keys(hash_a, hash_b, roles)
      remove_all = true
      hash_a.keys.each do |key|
        value_a, value_b = hash_a[key], hash_b[key]
        if !value_b
          if key =~ /\A[A-Z]/ && roles[key]
            # role missing but defined elsewhere: moved
            # do not remove
            remove_all = false
          elsif value_a.kind_of?(Hash)
            if filter_keys(hash_a[key], {}, roles)
              # nothing to be kept here
              hash_a.delete(key)
            end
          else
            # ignore missing key if we can ignore all
            hash_a.delete(key)
          end
        elsif value_a.kind_of?(Hash) && value_b.kind_of?(Hash)
          remove_all = false
          filter_keys(hash_a[key], hash_b[key], roles)
        end
      end
      remove_all
    end
end
