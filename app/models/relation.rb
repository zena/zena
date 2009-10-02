class Relation < ActiveRecord::Base
  validate        :valid_relation
  attr_accessor   :side, :link_errors, :start, :link
  attr_protected  :site_id
  has_many        :links, :dependent => :destroy

  # FIXME: validate uniqueness of source_role and target_role in scope site_id
  # FIXME: set kpath from class

  private
    def valid_relation
      unless visitor.is_admin?
        errors.add('base', 'You do not have the rights to do this.')
        return false
      end
      self[:site_id] = current_site[:id]
    end
end