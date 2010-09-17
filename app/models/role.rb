require 'property/stored_role'

class Role < ActiveRecord::Base
  include Property::StoredRole
  has_many :stored_columns, :class_name => 'Column', :dependent => :destroy
  has_and_belongs_to_many :nodes

  before_validation :set_defaults
  validate :check_can_save

  include RubyLess
  safe_method :columns => {:class => ['Column'], :method => 'columns.values', :nil => false}
  safe_method :name => String

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
end
