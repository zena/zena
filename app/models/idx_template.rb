=begin
This class is responsible for maintaining an index table Templates so that we can directly find a
given template for a kpath, format and mode. The indexing process is triggered by the Property
gem.
=end
class IdxTemplate < ActiveRecord::Base
  before_create :set_site_id

  def self.set_property_index(template, indices)
    if template.version.status >= Zena::Status::Pub
      # create or update index
      if index = first(:conditions => ['node_id = ?', template.id])
        if template.tkpath
          index.update_attributes(indices)
        else
          index.destroy
        end
      elsif template.tkpath
        create(indices.merge(:node_id => template.id, :version_id => template.version.id))
      end
    else
      # remove index
      delete_all(['node_id = ?', template.version.id])
    end
  end

  def self.delete_property_index(template)
    delete_all(['node_id = ?', template.id])
  end

  private
    def set_site_id
      self[:site_id] = current_site.id
    end
end