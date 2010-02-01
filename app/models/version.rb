class Version < ActiveRecord::Base
  include Zena::Use::AutoVersion
  include Zena::Use::Attachment
  include Zena::Use::MultiVersion::Version
  include Zena::Use::Workflow::Version

  before_create :set_site_id

  private
    def set_site_id
      self[:site_id] = current_site.id
    end
end
