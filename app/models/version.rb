class Version < ActiveRecord::Base

  # FIXME: Refactor
  include Zena::Refactor::ContentCalling

  include Zena::Use::AutoVersion
  include Zena::Use::Attachment
  include Zena::Use::MultiVersion::Version
  include Zena::Use::Workflow::Version
  include Dynamo::Attribute
  include Zena::Refactor::Version

  belongs_to :user

  attr_protected :node_id, :site_id, :content_id

  before_validation_on_create :set_defaults
  before_create :set_site_id

  def author
    user.contact
  end

  private
    def set_site_id
      self[:site_id] = current_site.id
    end

    def set_defaults
      self[:title] ||= node.name
    end
end
