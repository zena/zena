class Version < ActiveRecord::Base
  include Zena::Use::AutoVersion
  include Zena::Use::Attachment
  belongs_to :node

  def should_clone?
    # TODO
    changed? && Time.now > created_at + 30
  end
end
