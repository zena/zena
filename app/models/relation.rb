class Relation < ActiveRecord::Base
  before_validation :singularize_roles
  validate        :valid_relation
  attr_accessor   :side, :link_errors, :start, :link
  attr_protected  :site_id
  has_many        :links, :dependent => :destroy

  # FIXME: validate uniqueness of source_role and target_role in scope site_id
  # FIXME: set kpath from class

  def source_role
    source_unique ? self[:source_role] : self[:source_role].pluralize
  end

  def target_role
    target_unique ? self[:target_role] : self[:target_role].pluralize
  end

  private
    def singularize_roles
      self.source_role = self[:source_role].singularize unless self[:source_role].blank?
      self.target_role = self[:target_role].singularize unless self[:target_role].blank?
    end

    def valid_relation
      self.site_id = current_site[:id]

      unless visitor.is_admin?
        errors.add('base', 'You do not have the rights to do this.')
        return false
      end

      if self[:source_role].blank?
        if klass = VirtualClass.find_by_kpath(source_kpath)
          self.source_role = klass.to_s.underscore
        else
          klass = nil
        end
      else
        klass = VirtualClass.find_by_kpath(source_kpath)
      end

      errors.add(:source_kpath, 'invalid (could not find class)') unless klass

      if self[:target_role].blank?
        if klass = VirtualClass.find_by_kpath(target_kpath)
          self.target_role = klass.to_s.underscore
        else
          klass = nil
        end
      else
        klass = VirtualClass.find_by_kpath(target_kpath)
      end

      errors.add(:target_kpath, 'invalid (could not find class)') unless klass
    end
end