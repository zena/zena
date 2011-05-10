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
  validate :validate_role
  attr_accessible :name, :superclass, :icon

  after_save :expire_vclass_cache
  after_destroy :expire_vclass_cache

  include RubyLess
  # Columns defined in the role.
  safe_method :columns     => {:class => ['Column'], :method => 'defined_safe_columns'}

  safe_method :name => String

  # We use property to store index information, default values and such
  include Property

  class << self
    def export
      {'Node' => VirtualClass['Node'].export}
    end

    def import(definitions, delete = false)
      res = []
      post_import = []
      # Create everything in a transaction
      transaction do
        definitions.each do |name, definition|
          klass = VirtualClass[name]
          if !klass || !klass.real_class?
            # Error, missing superclass
            raise Exception.new("Importation needs to start with a real class: '#{name}' is not a real class.")
          else
            # start importing
            res += import_all(klass, definition, post_import)
          end
        end

        post_import.each do |l|
          l.call
        end
      end
      res
    end

    private
      def import_all(superclass, definitions, post_import)
        res = []
        definitions.each do |name, sub|
          next unless name =~ /\A[A-Z]/

          case sub['type']
          when 'Class'
            klass = VirtualClass[name]
            if klass && klass.real_class?
              res += import_all(klass, sub, post_import)
            else
              raise Exception.new("Unknown real class '#{name}'.")
            end
          when 'Role'
            res << import_role(superclass, name, sub)
          when 'VirtualClass'
            # VirtualClass
            res += import_vclass(superclass, name, sub, post_import)
          when nil
            klass = VirtualClass[name]
            if klass && klass.real_class?
              res += import_all(klass, sub, post_import)
            else
              res += import_vclass(superclass, name, sub, post_import)
            end
          else
            # Invalid type
            raise Exception.new("Cannot create '#{name}': invalid type '#{sub['type']}'.")
          end
        end
        res
      end

      def import_role(superclass, name, definition)
        role = ::Role.find_by_name_and_site_id(name, current_site.id)
        if role && role.class != ::Role
          # Change from vclass to role ?
          # Reject
          raise Exception.new("Cannot convert VirtualClass '#{name}' to Role.")
        elsif !role
          role = ::Role.new(:name => name, :superclass => superclass)
          role.save!
        end

        # 1. create or update attributes
        # noop

        # 2. create or update columns (never delete)
        if !role.new_record? && columns = definition['columns']
          role.import_columns(columns)
        end
        role
      end

      def import_vclass(superclass, name, definition, post_import)
        res = []
        vclass = ::Role.find_by_name_and_site_id(name, current_site.id)
        if vclass && vclass.class != VirtualClass
          # Change from role to vclass ?
          # Reject
          raiseException.new("Cannot convert Role '#{name}' to VirtualClass.")
        elsif !vclass
          vclass = VirtualClass.new(:name => name, :superclass => superclass)
        end

        # 1. create or update attributes
        VirtualClass.export_attributes.each do |key|
          if value = definition[key]
            vclass[key] = value
          else
            # We do not clear attributes (import is ADD/UPDATE only).
          end
        end
        vclass.save!
        res << vclass

        # 2. create or update columns (never delete)
        if columns = definition['columns']
          vclass.import_columns(columns)
        end

        # 3. create relations when all is done
        if relations = definition['relations']
          post_import << lambda do
            vclass.import_relations(relations)
          end
        end

        # 4. create or update sub-classes
        res += import_all(vclass, definition, post_import)
        res
      end
  end # class << self

  def real_class?
    false
  end

  def superclass
    if new_record?
      Node
    else
      VirtualClass.find_by_kpath(kpath)
    end
  end

  def superclass=(klass)
    if klass.kind_of?(VirtualClass) || klass = VirtualClass[klass]
      @superclass = klass
    else
      errors.add('superclass', 'invalid')
    end
  end

  # By default, all defined columns are safe (see )
  def defined_safe_columns
    @safe_column ||= defined_columns.values.sort {|a,b| a.name <=> b.name}
  end

  def export
    res = Zafu::OrderedHash.new
    res['type'] = real_class? ? 'Class' : type
    if !defined_columns.empty?
      res['columns'] = export_columns
    end
    res
  end

  def import_columns(columns)
    transaction do
      columns.each do |name, definition|
        column = secure(::Column) { ::Column.find_by_name(name) }
        if !column
          # create
          column = ::Column.new(:name => name)
        elsif column.role_id != self.id
          # error (do not move a column)
          raise Exception.new("Cannot set property '#{name}' in '#{self.name}': already defined in '#{column.role.name}'.")
        end
        column.role_id = self.id
        column.ptype   = definition['ptype']
        column.index   = definition['index']
        column.save!
      end
    end
  end

  def import_relations(relations)
    relations.each do |name, definition|
      relation = secure(::Relation) { ::Relation.first(
        :conditions => ['target_role = ? AND source_kpath = ? AND site_id = ?',
          name, self.kpath, self.site_id
        ]
      )}
      if !relation
        # create
        relation = ::Relation.new(:target_role => name, :source_kpath => self.kpath)
      end
      Relation::EXPORT_FIELDS.each do |key|
        value = definition[key]
        if !value.blank?
          relation[key] = value
        end
      end
      relation.save!
    end
  end

  private
    def set_defaults
      self[:type] = self.class.to_s
      self.site_id = visitor.site.id
    end

    def validate_role
      errors.add('base', 'You do not have the rights to change roles.') unless visitor.is_admin?
      if new_record?
        errors.add('superclass', 'invalid') unless @superclass.kind_of?(VirtualClass) && @superclass.kpath
      end

      if @superclass && self.class == ::Role
        self.kpath = @superclass.kpath
      end
    end

    def expire_vclass_cache
      VirtualClass.expire_cache!
    end

    def export_columns
      res = Zafu::OrderedHash.new

      defined_columns.keys.sort.each do |name|
        column = defined_columns[name]
        col = Zafu::OrderedHash.new
        col['ptype'] = column.ptype.to_s
        if column.index then
          col['index'] = column.index
        end
        res[name] = col
      end
      res
    end
end
