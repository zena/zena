require 'property/stored_role'

class Role < ActiveRecord::Base
  # Only store partial class name in 'type' field (not ::Role)
  self.store_full_sti_class = false

  include Property::StoredRole
  has_many :stored_columns, :class_name => 'Column', :dependent => :destroy
  has_and_belongs_to_many :nodes

  before_validation :set_defaults
  validate :check_can_save
  attr_accessible :name, :superclass, :icon

  after_save :expire_vclass_cache
  after_destroy :expire_vclass_cache

  include RubyLess
  # All columns defined for a VirtualClass (kpath based).
  safe_method :all_columns => {:class => ['Column'], :method => 'zafu_all_columns'}
  
  # Columns defined in the role.
  safe_method :columns     => {:class => ['Column'], :method => 'zafu_columns'}
  
  safe_method :name => String

  # We use property to store index information, default values and such
  include Property

  def superclass
    if new_record?
      Node
    else
      VirtualClass.find_by_kpath(kpath)
    end
  end

  def superclass=(klass)
    if k = Node.get_class(klass)
      self.kpath = k.kpath
    else
      errors.add('superclass', 'invalid')
    end
  end
  
  def zafu_all_columns
    @zafu_all_columns ||= (roles.flatten.map{|r| r.zafu_columns}).flatten.sort {|a,b| a.name <=> b.name}
  end

  def zafu_columns
    @zafu_columns ||= defined_columns.values.select do |c|
      # Allow all dynamic properties and all safe static properties
      !real_class || real_class.safe_method_type([c.name])
    end.sort {|a,b| a.name <=> b.name}
  end

  private
    def set_defaults
      self[:type] = self.class.to_s
      self.site_id = visitor.site.id
    end

    def check_can_save
      errors.add('base', 'You do not have the rights to change roles.') unless visitor.is_admin?
    end

    def expire_vclass_cache
      VirtualClass.expire_cache!
    end
end
