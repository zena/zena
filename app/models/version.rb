class Version < ActiveRecord::Base
  include Zena::Use::AutoVersion
  include Zena::Use::Attachment
  include Zena::Use::MultiVersion::Version
  include Zena::Use::Workflow::Version
end
