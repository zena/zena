# encoding: utf-8
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

    def clear_cache!
      @updated_at = current_site[:roles_updated_at].to_f
      @cache_by_id    = {}
      @cache_by_kpath = {}
      @cache_by_name  = {}
    end

    def stale?
      @updated_at < current_site[:roles_updated_at].to_f
    end

    def load_vclass(conditions)
      if kpath = conditions[:kpath]
        real_class = Node.native_classes[kpath]
      elsif name = conditions[:name]
        raise if name.kind_of?(Fixnum)
        real_class = Node.get_sub_class(name)
      end

      if real_class
        # Build vclass
        vclass = VirtualClass.new(:name => real_class.name)
        vclass.kpath      = real_class.kpath
        vclass.real_class = real_class
        vclass.include_role real_class
      else
        vclass = VirtualClass.first(:conditions => conditions.merge(:site_id => current_site.id))
      end

      if vclass
        vclass.load_attached_roles!
        @cache_by_id[vclass.id] = vclass if vclass.id
        @cache_by_kpath[vclass.kpath] = vclass
        @cache_by_kpath[vclass.name]  = vclass
      end

      vclass
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
  end

  self.caches_by_site ||= {}

  # Build a virtual class from a name and a hash of virtual class definitions. If
  # the superclass is in the data hash, it is built first.
  def self.build_virtual_class(klass, data)
    return data[klass]['result'] if data[klass].has_key?('result')
    if virtual_class = Node.get_class(klass)
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

  def self.export
    # TODO
  end

  # We use the VirtualClass to act as a proxy for the real class when resolving
  # RubyLess methods.
  def safe_method_type(signature, receiver = nil)
    if signature.size == 1 && (column = columns[signature.first])
      RubyLess::SafeClass.safe_method_type_for_column(column, true)
    else
      real_class.safe_method_type(signature, receiver)
    end
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

  # FIXME: how to make sure all sub-classes of Node are loaded before this is called ?
  def classes_for_form(opts={})
    all_classes(opts).map{|a,b| [a[0..-1].sub(/^#{self.kpath}/,'').gsub(/./,'  ') + b.to_s, b.to_s] } # white spaces are insecable spaces (not ' ')
  end

  def all_classes(opts={})
    classes = VirtualClass.find(:all, :conditions => ["site_id = ? AND create_group_id IN (?) AND kpath LIKE '#{self.kpath}%'", current_site[:id], visitor.group_ids]).map{|r| [r.kpath, r.name] }.sort{|a,b| a[0] <=> b[0] }
    if opts[:without]
      reject_kpath =  opts[:without].split(',').map(&:strip).map {|name| Node.get_class(name) }.compact.map { |kla| kla.kpath }.join('|')
      classes.reject! {|k,c| k =~ /^#{reject_kpath}/ }
    end
    classes
  end

  # check inheritance chain through kpath
  def kpath_match?(kpath)
    self.kpath =~ /^#{kpath}/
  end

  def superclass
    if new_record?
      Node
    else
      Node.get_class_from_kpath(kpath[0..-2])
    end
  end

  def superclass=(klass)
    if k = Node.get_class(klass)
      @superclass = k
    else
      errors.add('superclass', 'invalid')
    end
  end

  # Build new nodes instances of this VirtualClass
  def new_instance(hash={})
    real_class.new.tap do |obj|
      obj.kpath = self.kpath
      obj.vclass_id = self.id
      obj.virtual_class = self
      obj.attributes = hash
    end
  end

  # Create new nodes instances of this VirtualClass
  def create_instance(*args)
    obj = self.new_instance(*args)
    obj.save
    obj
  end

  def real_class
    klass = Module::const_get(self[:real_class])
    raise NameError unless klass.ancestors.include?(Node)
    klass
  end

  def import_result
    @import_result || errors[:base]
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
          if found = Node.get_class_from_kpath(try_kpath)
            if found.kind_of?(VirtualClass) && found[:id] == self[:id]
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
