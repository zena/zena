class VirtualClass < ActiveRecord::Base
  belongs_to    :create_group, :class_name => 'Group', :foreign_key => 'create_group_id'
  validate      :valid_virtual_class
  include Zena::Use::Relations::ClassMethods

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

  # new instances, not virtual classes
  def new_instance(hash={})
    obj = real_class.new(:vclass_id => self[:id])
    obj.attributes = hash
    obj
  end

  alias new new_instance

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

  # create instances, not virtual classes
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

  private
    def valid_virtual_class
      if self[:name].blank?
        errors.add('name', "can't be blank")
        return false
      end
      @superclass ||= self.superclass

      if new_record? || self[:name] != old[:name] || @superclass != old.superclass
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
        self[:kpath]      = kpath
      end

      self[:site_id]    = current_site[:id]
      self[:real_class] = get_real_class(@superclass)

      unless (secure!(Group) { Group.find(self[:create_group_id]) } rescue nil)
        errors.add('create_group_id', 'invalid group')
      end
      unless self[:real_class]
        errors.add('superclass', 'invalid')
      end
      return errors.empty?
    end

    def get_real_class(klass)
      klass.kind_of?(VirtualClass) ? get_real_class(klass.superclass) : klass.to_s
    end

    def old
      @old ||= self.class.find(self[:id])
    end
end
