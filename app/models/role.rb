require 'property/stored_role'

class Role < ActiveRecord::Base
  include Property::StoredRole
  has_many :stored_columns, :class_name => 'Column', :dependent => :destroy
  has_and_belongs_to_many :nodes

  before_validation :set_defaults
  validate :check_can_save

  private
    def set_defaults
      self.site_id = visitor.site.id
    end

    def check_can_save
      errors.add('base', 'You do not have the rights to change roles.') unless visitor.is_admin?
    end
end
