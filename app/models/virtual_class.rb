# encoding: utf-8

# The virtual class holds type information and other attributes to build indices
# and computed properties. This class acts as the "schema" for nodes.
#
# Since this class also _uses_ Property to store some of it's data, confusion must not
# be made between the VirtualClass as a schema (containing Node property definitions) and
# the VirtualClass' own schema.
class VirtualClass < Role
  attr_accessor :import_result
  belongs_to    :create_group, :class_name => 'Group', :foreign_key => 'create_group_id'
  validate      :valid_virtual_class
  attr_accessible :create_group_id, :auto_create_discussion

  include Property::StoredSchema
  include Zena::Use::Relations::ClassMethods
  include Zena::Use::Fulltext::VirtualClassMethods
  include Zena::Use::PropEval::VirtualClassMethods
  include Zena::Use::ScopeIndex::VirtualClassMethods
  
  safe_method :roles => {:class => ['Role'], :method => 'zafu_roles'}

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

    # Import a hash of virtual class definitions and try to build the virtual classes.
    def import(data)
      data.keys.map do |klass|
        build_virtual_class(klass, data)
      end
    end

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

    # Build a virtual class from a name and a hash of virtual class definitions. If
    # the superclass is in the data hash, it is built first.
    def build_virtual_class(klass, data)
      return data[klass]['result'] if data[klass].has_key?('result')
      if virtual_class = VirtualClass[klass]
        virtual_class = virtual_class.dup
        if virtual_class.superclass.to_s == data[klass]['superclass']
          virtual_class.import_result = 'same'
          return data[klass]['result'] = virtual_class
        else
          virtual_class.errors.add(:base, 'conflict')
          return data[klass]['result'] = virtual_class
        end
      else
        superclass_name = data[klass]['superclass']
        if data[superclass_name]
          superclass = build_virtual_class(superclass_name, data)
          unless superclass.errors.empty?
            virtual_class = VirtualClass.new(:name => klass, :superclass => superclass_name, :create_group_id => current_site.public_group_id)
            virtual_class.errors.add(:base, 'conflict in superclass')
            return data[klass]['result'] = virtual_class
          end
        elsif superclass = Node.get_class(superclass_name)
          # ok
        else
          virtual_class = VirtualClass.new(:name => klass, :superclass => superclass_name, :create_group_id => current_site.public_group_id)
          virtual_class.errors.add(:base, 'missing superclass')
          return data[klass]['result'] = virtual_class
        end

        # build
        create_group_id = superclass.id ? superclass.create_group_id : current_site.public_group_id
        virtual_class = create(data[klass].merge(:name => klass, :create_group_id => create_group_id))
        virtual_class.import_result = 'new'
        return data[klass]['result'] = virtual_class
      end
    end

    def export
      # TODO
    end
  end

  self.caches_by_site ||= {}


  # We use the VirtualClass to act as a proxy for the real class when resolving
  # RubyLess methods.
  def safe_method_type(signature, receiver = nil)
    if signature.size == 1 && (column = columns[signature.first])
      RubyLess::SafeClass.safe_method_type_for_column(column, true)
    else
      real_class.safe_method_type(signature, receiver)
    end
  end

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

  def icon=(txt)
    self[:icon] = txt.gsub('..', '.') # SECURITY
  end

  # check inheritance chain through kpath
  def kpath_match?(kpath)
    self.kpath =~ /^#{kpath}/
  end

  # Proxy methods for real class --------------

  def superclass
    if new_record?
      real_class || Node
    else
      VirtualClass.find_by_kpath(kpath[0..-2])
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
    else
      real_class < other_class
    end
  end


  # Return the pseudo sql query compiler.
  def query_compiler
    real_class.query_compiler
  end
  
  # Build pseudo sql query.
  def build_query(*args)
    real_class.build_query(*args)
  end
  
  # Execute find
  def do_find(*args)
    real_class.do_find(*args)
  end

  def superclass=(klass)
    if k = VirtualClass[klass]
      @superclass = k
    else
      errors.add('superclass', 'invalid')
    end
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

  def import_result
    @import_result || errors[:base]
  end

  # List all roles ordered by ascending kpath and name
  def zafu_roles
    @zafu_roles ||= roles.flatten.uniq.reject do |r|
      r.zafu_columns.empty?
    end.sort do |a, b|
      if a.kpath == b.kpath
        a.name <=> b.name
      else
        a.kpath <=> b.kpath
      end
    end
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
      return if !errors.empty?
      @superclass ||= self.superclass

      if new_record? || name_changed? || @superclass != old.superclass
        index = 0
        kpath = nil
        while index < self[:name].length
          try_kpath = @superclass.kpath + self[:name][index..index].upcase
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
end
