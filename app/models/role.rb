require 'property/stored_role'

class Role < ActiveRecord::Base
  # We define 'klass' in the Role used by the real classes so that property methods can be
  # defined.
  attr_accessor :klass

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
  # Columns defined in the role.
  safe_method :columns     => {:class => ['Column'], :method => 'defined_safe_columns'}

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

  # By default, all defined columns are safe (see )
  def defined_safe_columns
    @safe_column ||= defined_columns.values.sort {|a,b| a.name <=> b.name}
  end

  def export
    res = {
      'name'       => name,
      'superclass' => superclass.name,
      'kpath'      => kpath,
      'type'       => type,
    }
    if !defined_columns.empty?
      res['columns'] = export_columns
    end
    res
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

    def export_columns
      res = {}

      defined_columns.each do |name, column|
        col = {'ptype' => column.ptype.to_s}
        if column.index then
          col['index'] = column.index
        end
        res[name] = col
      end
      res
    end
end
