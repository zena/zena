class Link < ActiveRecord::Base
  #TODO: use a registration when a class calls 'link' to avoid this
  #TODO: test
  def self.roles_for_form
    roles = []
    roles << ['tag', 'tag']
    roles << ['hot', 'hot']
    roles
  end
end
