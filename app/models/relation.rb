class Relation < ActiveRecord::Base
  validate        :valid_relation
  attr_accessor   :side, :link_errors, :start, :link
  attr_protected  :site_id
  has_many        :links, :dependent => :destroy

  # FIXME: validate uniqueness of source_role and target_role in scope site_id
  # FIXME: set kpath from class

  private
    def valid_relation
      self.site_id = current_site[:id]

      unless visitor.is_admin?
        errors.add('base', 'You do not have the rights to do this.')
        return false
      end

      if source_role.blank?
        if klass = Node.get_class_from_kpath(source_kpath)
          self.source_role = klass.to_s.underscore
        else
          klass = nil
        end
      else
        klass = Node.get_class_from_kpath(source_kpath)
      end

      errors.add(:source_kpath, 'invalid (could not find class)') unless klass

      if target_role.blank?
        if klass = Node.get_class_from_kpath(target_kpath)
          self.target_role = klass.to_s.underscore
        else
          klass = nil
        end
      else
        klass = Node.get_class_from_kpath(target_kpath)
      end

      errors.add(:target_kpath, 'invalid (could not find class)') unless klass
    end
end