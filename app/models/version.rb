require 'versions'

class Version < ActiveRecord::Base
  include RubyLess
  safe_attribute     :created_at, :updated_at, :publish_from, :status, :lang

  # We need to include Property::Base so that we can read the properties that
  # we store (useful when listing versions or comparing them).
  include Property::Base
  property do |p|
    p.string 'title'
    p.string 'summary'
    p.string 'text'
  end
  safe_property :title, :summary, :text

  include Versions::Auto
  # include Versions::Destroy

  # FIXME: Refactor
  include Zena::Refactor::ContentCalling

  #include Zena::Use::SharedAttachment
  #set_attachment_class 'Zena::Attachment'

  include Zena::Use::Workflow::Version
  include Zena::Refactor::Version

  belongs_to :user

  attr_protected :node_id, :site_id, :content_id

  before_validation_on_create :set_defaults
  before_create :set_site_id

  def cloned
    # set number
    # last_record = self[:node_id] ? self.connection.select_one("select number from #{self.class.table_name} where node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1") : nil
    # self[:number] = (last_record || {})['number'].to_i + 1

    set_defaults
  end

  def author
    user.contact
  end

  private
    def set_site_id
      self[:site_id] = current_site.id
    end

    def set_defaults
      self[:title] ||= node.name

      # set author
      self[:user_id] = visitor.id
      self[:lang]    = visitor.lang unless lang_changed?
      self[:site_id] = current_site.id
    end
end
