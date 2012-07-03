class Column < ActiveRecord::Base
  include RubyLess
  include Property::StoredColumn
  TYPES_FOR_FORM   = %w{string datetime integer float hash}

  INDICES_FOR_FORM = %w{string ml_string datetime integer float}

  FIELD_INDICES = []

  belongs_to :role
  before_validation :set_defaults

  validates_presence_of :role
  validates_uniqueness_of :name, :scope => :site_id
  validate :name_not_in_models
  validate :valid_ptype_and_index

  after_save :expire_vclass_cache
  after_destroy :expire_vclass_cache

  safe_method :name => String
  safe_method :type => {:class => String, :method => 'ptype.to_s'}

  class << self
    include Zena::Acts::Secure

    def roles_for_form
      if roles = secure(Role) { Role.all(:order => 'name ASC') }
        roles.map do |role|
          [role.name, role.id]
        end
      else
        []
      end
    end

    def indices_for_form
      [
        ['field',
          FIELD_INDICES.map {|i| [i, ".#{i}"]}],
        ['key/value',
          INDICES_FOR_FORM.map {|i| [i, i]}]
      ]
    end

    # Declare a new index table or field
    def add_field_index(*args)
      args.flatten.each do |idx|
        FIELD_INDICES << idx
      end
    end
  end

  def kpath
    @kpath ||= role.kpath
  end

  # Used to display index name in forms
  def index_name
    self.index.to_s.gsub(/\A\./,'')
  end

  def export
    root = current_site.root_node
    {
      'ptype' => ptype,
      'index' => index,
      'comment' => root.unparse_assets(comment, root, 'comment')
    }
  end

  def type_cast(value)
    if value.blank?
      return nil
    end
    if ptype == 'datetime'
      if value.kind_of?(Time)
        value
      elsif value.kind_of?(String)
        value.to_utc(_(Zena::Use::Dates::DATETIME), visitor.tz)
      else
        nil
      end
    elsif ptype == 'hash'
      if value.kind_of?(Hash)
        StringHash.from_hash(value)
      elsif value.kind_of?(String)
        StringHash.from_string(value)
      end
    else
      nil
    end
  end
  
  def merge_hash(orig, value)
    unless orig.kind_of?(StringHash)
      orig = StringHash.from_hash(orig)
    end
    orig.merge!(value)
    return orig
  end
  
  def klass
    if ptype == 'hash'
      StringHash
    else
      nil
    end
  end

  protected
    def set_defaults
      self.index = nil if index.blank?
      self[:site_id] = current_site.id
    end

    def name_not_in_models
      Node.native_classes.to_a.sort{|a,b| a[0] <=> b[0]}.each do |kpath, klass|
        name, set_name = self.name, "#{self.name}="
        if column = klass.schema.columns[self.name]
          # find column origin
          errors.add(:name, _('has already been taken in %s') % column.role.name)
          break
        elsif self.name =~ %r{_ids?$}
          errors.add(:name, _('invalid (cannot end with _id or _ids)'))
          break
        elsif klass.method_defined?(name)     || klass.protected_method_defined?(name)     || klass.private_method_defined?(name) ||
           klass.method_defined?(set_name) || klass.protected_method_defined?(set_name) || klass.private_method_defined?(set_name)
          errors.add(:name, _('invalid (method defined in %s)') % klass.to_s)
          break
        end
      end
    end

    def expire_vclass_cache
      VirtualClass.expire_cache!
    end

    def valid_ptype_and_index
      if !TYPES_FOR_FORM.include?(self.ptype)
        errors.add(:ptype, 'invalid')
      end

      if !index.blank? && !(INDICES_FOR_FORM + FIELD_INDICES.map {|i| ".#{i}"}).include?(index)
        errors.add(:index, 'invalid')
      end
    end
end
