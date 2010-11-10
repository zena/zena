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
  safe_method :columns => {:class => ['Column'], :method => 'columns.values', :nil => false}
  safe_method :name => String

  # We use property to store index information, default values and such
  include Property

  def superclass
    if new_record?
      Node
    else
      Node.get_class_from_kpath(kpath)
    end
  end

  def superclass=(klass)
    if k = Node.get_class(klass)
      self.kpath = k.kpath
    else
      errors.add('superclass', 'invalid')
    end
  end


  private
    def set_defaults
      self.site_id = visitor.site.id
    end

    def check_can_save
      errors.add('base', 'You do not have the rights to change roles.') unless visitor.is_admin?
    end

    def expire_vclass_cache
      VirtualClass.expire_cache!
    end
end
