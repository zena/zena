class Version < ActiveRecord::Base
  include Zena::Use::Dates::ModelMethods
  parse_date_attribute :publish_from

  include RubyLess
  safe_attribute     :created_at, :updated_at, :publish_from, :status, :lang
  safe_method        :node => 'Node', :id => {:class => Number, :method => 'number'},
                     :number => Number, :user => 'User',
                     :author => {:class => 'User', :method => 'user'}

  # We need to include Property::Base so that we can read the properties that
  # we store (useful when listing versions or comparing them).
  include Property::Base

  # Should be the same serialization as in Node
  include Property::Serialization::JSON

  property do |p|
    p.string 'title'
    p.string 'summary'
    p.string 'text'
  end
  safe_property :title, :summary, :text

  include Versions::Auto
  include Versions::Destroy

  include Zena::Use::Workflow::VersionMethods

  belongs_to :user
  belongs_to :node

  attr_protected :node_id, :site_id, :attachment_id, :user_id

  before_validation_on_create :set_defaults
  before_create :set_site_id
  validate :valid_version

  # node_with_secure is defined in node.rb. It is an ugly fix
  # related to the circular dependency between Node and Version

  def cloned
    set_defaults
  end


  def previous_number
    if node_id = self[:node_id]
      last_record = self.connection.select_one("SELECT number FROM #{self.class.table_name} WHERE node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1")
      (last_record || {})['number'].to_i
    else
      nil
    end
  end

  def author
    user.contact
  end

  def mark_for_destruction
    super
    self.status = -1
  end

  private
    def set_site_id
      self[:site_id] = current_site.id
    end

    def set_defaults
      # set author
      self[:user_id] = visitor.id
      self[:lang]    = visitor.lang unless lang_changed?
      self[:site_id] = current_site.id
    end

    def valid_version
      errors.add('lang', 'invalid') unless visitor.site.lang_list.include?(self[:lang])
      errors.add('node', "can't be blank") unless self[:node_id] || @node
    end

    def check_can_destroy
      true # we use Node validations to check destruction
    end
end
