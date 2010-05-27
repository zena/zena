# encoding: utf-8
class VirtualClass < Role
  attr_accessor :import_result
  belongs_to    :create_group, :class_name => 'Group', :foreign_key => 'create_group_id'
  validate      :valid_virtual_class
  include Zena::Use::Relations::ClassMethods

  # Import a hash of virtual class definitions and try to build the virtual classes.
  def self.import(data)
    data.keys.map do |klass|
      build_virtual_class(klass, data)
    end
  end

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
      create_group_id = superclass.kind_of?(VirtualClass) ? superclass.create_group_id : current_site.public_group_id
      virtual_class = create(data[klass].merge(:name => klass, :create_group_id => create_group_id))
      virtual_class.import_result = 'new'
      return data[klass]['result'] = virtual_class
    end
  end

  def self.export
    # TODO
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
    real_class.new(hash.merge(:kpath => self.kpath, :vclass_id => self.id))
  end

  # Create new nodes instances of this VirtualClass
  def create_instance(*args)
    if @scope
      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      real_class.send(:with_exclusive_scope, @scope) {
        obj = self.new_instance(*args)
        obj.save
        obj
      }
    else
      obj = self.new_instance(*args)
      obj.save
      obj
    end
  end

  def real_class
    klass = Module::const_get(self[:real_class])
    raise NameError unless klass.ancestors.include?(Node)
    klass
  end

  def with_exclusive_scope(scope, &block)
    @scope = scope
    res = yield
    @scope = nil
    res
  end

  def import_result
    @import_result || errors[:base]
  end

  private
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
