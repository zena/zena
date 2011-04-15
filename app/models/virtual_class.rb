# encoding: utf-8

# The virtual class holds type information and other attributes to build indices
# and computed properties. This class acts as the "schema" for nodes.
#
# Since this class also _uses_ Property to store some of it's data, confusion must not
# be made between the VirtualClass as a schema (containing Node property definitions) and
# the VirtualClass' own schema.
#
# The roles in the vclass contain self, super and all the attached roles like this (roles for
# the Letter virtual class):
#
#     [
#       <VirtualClass:'Letter' paper, search_mono, search>,
#       [
#         <VirtualClass:'Note' >,
#    -->  <Role:'Note' >,
#         [
#           <VirtualClass:'Node' >,
#    -->    <Role:'Node' cached_role_ids, title, text, summary>,
#           <Role:'Original' weight, origin, tz>,
#           <Role:'Task' assigned>
#         ]
#       ]
#     ]
#
# Elements marked with '-->' above are the 'schema' roles used by the real classes to store
# ruby declared properties. Since Zena is multi-site, there is one VirtualClass instance of
# the real classes for each site: this is why the ruby declarations are not stored in the
# VirtualClass itself for real classes.
#
class VirtualClass < Role
  EXPORT_ATTRIBUTES = %w{idx_class idx_scope idx_reverse_scope}
  attr_accessor :import_result
  belongs_to    :create_group, :class_name => 'Group', :foreign_key => 'create_group_id'
  validate      :valid_virtual_class
  attr_accessible :create_group_id, :auto_create_discussion
  after_update  :propagate_kpath_change

  include Property::StoredSchema
  include Zena::Use::Relations::ClassMethods
  include Zena::Use::Fulltext::VirtualClassMethods
  include Zena::Use::PropEval::VirtualClassMethods
  include Zena::Use::ScopeIndex::VirtualClassMethods

  safe_method  :roles     => {:class => ['Role'], :method => 'sorted_roles'}
  safe_method  :relations => {:class => ['RelationProxy'], :method => 'all_relations'}
  safe_method  [:relations, String] => {:class => ['RelationProxy'], :method => 'filtered_relations'}
  # All columns defined for a VirtualClass (kpath based).
  safe_method :all_columns => {:class => ['Column'], :method => 'safe_columns'}

  class Cache
    def initialize
      clear_cache!
    end

    def find_by_id(id)
      clear_cache! if stale?

      @cache_by_id[id] || load_vclass(:id => id)
    end

    def find_by_kpath(kpath)
      clear_cache! if stale?

      @cache_by_kpath[kpath] || load_vclass(:kpath => kpath)
    end

    def find_by_name(name)
      clear_cache! if stale?

      @cache_by_name[name] || load_vclass(:name => name)
    end

    def all_classes(base_kpath = 'N', without_list = nil)
      load_all_classes!

      filter_on = %r{\A#{base_kpath}}

      if without_list
        regexp = []
        without_list.split(',').map(&:strip).each do |without|
          if filter_class = VirtualClass[without]
            regexp << "\\A#{filter_class.kpath}"
          end
        end
        unless regexp.empty?
          filter_off = %r{\A#{regexp.join('|')}}
        end
      end

      @cache_by_kpath.values.select do |vclass|
        (vclass.kpath =~ filter_on) &&
        (filter_off.nil? || !(vclass.kpath =~ filter_off))
      end.sort {|a, b| a.kpath <=> b.kpath}
    end

    def clear_cache!
      @updated_at = current_site[:roles_updated_at].to_f
      @cache_by_id    = {}
      @cache_by_kpath = {}
      @cache_by_name  = {}
      @all_classes_loaded = false
    end

    def load_all_classes!
      return if @all_classes_loaded

      conditions = [["site_id = ?"], current_site.id]
      unless @cache_by_id.empty?
        conditions[0] << "id NOT IN (?)"
        conditions << @cache_by_id.keys
      end

      conditions[0] = conditions[0].join(' AND ')

      Node.native_classes.each do |kpath, real_class|
        load_roles_and_cache(build_vclass_from_real_class(real_class))
      end

      VirtualClass.all(
        :conditions => conditions,
        :order      => 'kpath ASC').each do |vclass|
        load_roles_and_cache(vclass)
      end

      @all_classes_loaded = true
    end

    def stale?
      @updated_at < current_site[:roles_updated_at].to_f
    end

    def load_vclass(conditions)
      if kpath = conditions[:kpath]
        real_class = Node.native_classes[kpath]
      elsif name = conditions[:name]
        raise if name.kind_of?(Fixnum)
        real_class = Node.native_classes_by_name[name]
      end

      if real_class
        vclass = build_vclass_from_real_class(real_class)
      else
        vclass = VirtualClass.first(:conditions => conditions.merge(:site_id => current_site.id))
      end

      load_roles_and_cache(vclass) if vclass

      vclass
    end

    def build_vclass_from_real_class(real_class)
      vclass = VirtualClass.new(:name => real_class.name)
      vclass.kpath      = real_class.kpath
      vclass.real_class = real_class
      vclass.include_role real_class.schema
      vclass.instance_variable_set(:@is_real_class, true)
      vclass.site_id = current_site.id
      vclass
    end

    def load_roles_and_cache(vclass)
      vclass.load_attached_roles!
      @cache_by_id[vclass.id] = vclass if vclass.id
      @cache_by_kpath[vclass.kpath] = vclass
      @cache_by_name[vclass.name]  = vclass
    end
  end # Cache

  class << self
    attr_accessor :caches_by_site

    def [](name)
      find_by_name(name)
    end

    def find_by_id(id)
      (self.caches_by_site[current_site.id] ||= Cache.new).find_by_id(id)
    end

    def find_by_kpath(kpath)
      (self.caches_by_site[current_site.id] ||= Cache.new).find_by_kpath(kpath)
    end

    def find_by_name(name)
      (self.caches_by_site[current_site.id] ||= Cache.new).find_by_name(name)
    end

    def expire_cache!
      Zena::Db.set_attribute(current_site, 'roles_updated_at', Time.now.utc)
      self.caches_by_site[current_site.id] = Cache.new
    end

    def all_classes(base_kpath = 'N', without_list = nil)
      (self.caches_by_site[current_site.id] ||= Cache.new).all_classes(base_kpath, without_list)
    end
  end

  self.caches_by_site ||= {}

  # FIXME: how to make sure all sub-classes of Node are loaded before this is called ?
  # TODO: move into helper
  def classes_for_form(opts={})
    group_ids = visitor.group_ids
    if klass = opts.delete(:class)
      if klass = VirtualClass[klass]
        base_kpath = klass.kpath
      else
        base_kpath = self.kpath
      end
    else
      base_kpath = self.kpath
    end

    kpath_len = base_kpath.size

    VirtualClass.all_classes(base_kpath, opts[:without]).map do |vclass|
      if vclass.create_group_id.nil? || group_ids.include?(vclass.create_group_id)
        # white spaces are insecable spaces (not ' ')
        a, b = vclass.kpath, vclass.name
        [('  ' * (a.size - kpath_len)) + b, b]
      else
        nil
      end
    end.compact
  end

  # Include all roles into the this schema. By including the superclass
  # and all roles related to this class.
  def load_attached_roles!
    return if @attached_roles_loaded

    super_kpath = kpath[0..-2]
    if super_kpath != ''
      include_role VirtualClass.find_by_kpath(super_kpath)
    end

    attached_roles.each do |role|
      include_role role
    end

    @attached_roles_loaded = true
  end

  def to_s
    name
  end

  def export
    res = super
    EXPORT_ATTRIBUTES.each do |k|
      value = self[k]
      next if value.blank?
      res[k] = value
    end
    subclasses = secure(::Role) do
      ::Role.find(:all, :conditions => [
        'kpath LIKE ? OR (kpath = ? AND id <> ?)', "#{kpath}_", kpath, self.id.to_i
      ], :order => 'kpath ASC')
    end
    if real_class?
      # insert native subclasses
      Node.native_classes.each do |kpath, klass|
        if kpath =~ /\A#{self.kpath}.\Z/
          subclasses ||= []
          subclasses << VirtualClass[klass.name]
        end
      end

      if subclasses
        subclasses.sort! do |a,b|
          if a.class != b.class
            # Roles before subclasses
            b.class <=> a.class
          else
            a.kpath <=> b.kpath
          end
        end
      end
    end

    if subclasses
      subclasses.each do |sub|
        res[sub.name] = sub.export
      end
    end

    relations = Relation.all(
      :conditions => ['source_kpath = ? AND site_id = ?', kpath, site_id],
      :order      => 'target_role ASC'
    )
    if !relations.empty?
      res['relations'] = list = Zafu::OrderedHash.new
      relations.each do |rel|
        list[rel.target_role] = rel.export
      end
    end
    res
  end

  def icon=(txt)
    self[:icon] = txt.gsub('..', '.') # SECURITY
  end

  # check inheritance chain through kpath
  def kpath_match?(kpath)
    self.kpath =~ /^#{kpath}/
  end

  # Return true if the class reflects a real class (proxy for Ruby class).
  def real_class?
    @is_real_class
  end

  # Proxy methods for real class --------------

  # We use the VirtualClass to act as a proxy for the real class when resolving
  # RubyLess methods. If the class reflects a 'real' class, only the methods
  # explicitely declared as safe are safe. If the VirtualClass reflects a virtual
  # class, all properties are considered safe.
  def safe_method_type(signature, receiver = nil)

    if signature.size == 1
      method = signature.first
      if receiver && (query = receiver.opts[:query])
        if query.select_keys.include?(method)
          # Resolve by using information in the SELECT part
          # of the custom_query that found this node

          # In order to use types other then String, we use the overwritten property's
          # type.
          if type = safe_column_types[method]
            return type.merge(:method => "attributes[#{method.inspect}]", :nil => true)
          elsif type = real_class.safe_method_type(signature)
            return type.merge(:nil => true)
          else
            return {:class => String, :method => "attributes[#{method.inspect}]", :nil => true}
          end
        end
      end
      if type = safe_column_types[method]
        return type
      end
    end

    real_class.safe_method_type(signature, receiver)
  end

  # Return safe columns including super class's safe columns
  def defined_safe_columns
    @defined_safe_columns ||= if real_class?
      # Get columns from the 'native' schema of the real class (this schema is a Property::Role,
      # not a VirtualClass or ::Role).
      #
      # Only columns explicitly declared safe are safe here
      real_class.schema.defined_columns.values.select do |col|
        real_class.safe_method_type([col.name])
      end.sort {|a,b| a.name <=> b.name}
    else
      super
    end
  end

  # Return safe columns including super class's safe columns. The columns are
  # sorted by kpath, origin (VirtualClass first, Role next) and name.
  def safe_columns
    @safe_columns ||= begin
      (superclass.kind_of?(VirtualClass) ? superclass.safe_columns : []) +
      defined_safe_columns +
      attached_roles.map(&:defined_safe_columns).flatten.sort {|a,b| a.name <=> b.name}
    end
  end

  # Returns a hash of all column types that are RubyLess safe (declared as safe in a real class
  # or just dynamic properties declared in the DB). In the Role: everything is safe
  # (see VirtualClass#safe_column_types).
  def safe_column_types
    @safe_column_types ||= Hash[*safe_columns.map do |column|
      [column.name, RubyLess::SafeClass.safe_method_type_for_column(column, true)]
    end.flatten]
  end

  # List all roles ordered by ascending kpath and name
  def sorted_roles
    @sorted_roles ||= begin
      res = []
      if superclass.kind_of?(VirtualClass)
        res << superclass.sorted_roles
      end
      res << self unless defined_safe_columns.empty?
      attached_roles.sort{|a,b| a.name <=> b.name}.each do |role|
        res << role unless role.defined_safe_columns.empty?
      end
      res.flatten!
      res
    end
  end

  # Return virtual class' super class or Node for the virtual class of
  # Node.
  def superclass
    if kpath && kpath.size > 1
      VirtualClass.find_by_kpath(kpath[0..-2])
    else
      Node
    end
  end

  # This is used by RubyLess in method signatures: [:zen_path, #<VirtualClass 'Post'>] ---> [:zen_path, Node]
  def ancestors
    @ancestors ||= [real_class] + real_class.ancestors
  end

  # Test ancestry
  def <=(other_class)
    if other_class.kind_of?(VirtualClass)
      kpath = other_class.kpath
      self.kpath[0..(kpath.length-1)] == kpath
    else
      real_class <= other_class
    end
  end

  # Test ancestry
  def <(other_class)
    if other_class.kind_of?(VirtualClass)
      kpath = other_class.kpath
      self.kpath != kpath && self.kpath[0..(kpath.length-1)] == kpath
    elsif real_class.kpath != self.kpath
      # Sub class of real_class
      real_class <= other_class
    else
      # VirtualClass of the real_class
      real_class < other_class
    end
  end


  # Return the SQLiss query compiler.
  def query_compiler
    real_class.query_compiler
  end

  # Build SQLiss query.
  def build_query(*args)
    real_class.build_query(*args)
  end

  # Execute find
  def do_find(*args)
    real_class.do_find(*args)
  end

  # Build new nodes instances of this VirtualClass
  def new_instance(hash={})
    real_class.new(hash, self)
  end

  # Create new nodes instances of this VirtualClass
  def create_instance(*args)
    obj = self.new_instance(*args)
    obj.save
    obj
  end

  def real_class
    @real_class ||= begin
      klass = Module::const_get(self[:real_class] || 'Node')
      raise NameError unless klass.ancestors.include?(Node)
      klass
    end
  end

  def real_class=(klass)
    @real_class = klass
  end

  # List all relations that can be set for this class, filtering by
  # relation group.
  def filtered_relations(group_filter)
    all_relations(nil, group_filter)
  end

  # Cache index groups
  def index_groups
    @index_groups ||= super
  end

  protected
    def rebuild_kpath(superclass)
      index = 0
      kpath = nil
      while index < self[:name].length
        try_kpath = superclass.kpath + self[:name][index..index].upcase
        if found = VirtualClass.find_by_kpath(try_kpath)
          if found.id && found.id == self[:id]
            kpath = try_kpath
            break
          end
        else
          kpath = try_kpath
          break
        end
        index += 1
      end
      errors.add('name', 'invalid (could not build unique kpath)') unless kpath
      self[:kpath] = kpath
    end

  private
    def attached_roles
      ::Role.all(
        :conditions => ['kpath = ? AND site_id = ? AND type != ?',
          kpath, current_site.id, 'VirtualClass'],
        :order => 'kpath ASC'
      )
    end

    def valid_virtual_class
      if create_group_id.blank? && new_record?
        self.create_group_id = current_site.public_group_id
      end

      return if !errors.empty?
      @superclass ||= self.superclass

      if real_class? || name_changed? || @superclass != old.superclass
        rebuild_kpath(@superclass)
      end

      self[:real_class] = get_real_class(@superclass)

      unless (secure!(Group) { Group.find(self[:create_group_id]) } rescue nil)
        errors.add('create_group_id', 'invalid group')
      end

      unless self[:real_class]
        errors.add('superclass', 'invalid')
      end
    end

    def get_real_class(klass)
      klass.kind_of?(VirtualClass) ? get_real_class(klass.superclass) : klass.to_s
    end

    def old
      @old ||= self.class.find(self[:id])
    end

    def propagate_kpath_change
      if kpath_changed?
        old_kpath = kpath_was
        Zena::Db.execute "UPDATE nodes SET kpath = '#{kpath}' WHERE vclass_id = #{self.id} AND site_id = #{current_site.id}"
        Zena::Db.execute "UPDATE roles SET kpath = '#{kpath}' WHERE kpath = '#{old_kpath}' AND site_id = #{current_site.id} AND (type = 'Role' or type IS NULL)"
        # Find templates
        idx_templates = IdxTemplate.all(
          :conditions => ['tkpath = ? AND site_id = ?', old_kpath, site_id]
        )

        if !idx_templates.empty?
          # update related templates
          if templates = secure(Node) { Node.all(
              :conditions => "id IN (#{idx_templates.map{|r| r.node_id}.join(',')})")}
            templates.each do |t|
              t.rebuild_tkpath(self)
              # What if this fails ? Abort all ?
              t.save!
            end
          end
        end

        # Sub-classes
        if sub_classes = secure(VirtualClass) { VirtualClass.all(
            :conditions => ['kpath LIKE ?', "#{old_kpath}_"]
            )}
          sub_classes.each do |sub|
            sub.rebuild_kpath(self)
            # What if this fails ? Abort all ?
            sub.save!
          end
        end
      end
    end
end
