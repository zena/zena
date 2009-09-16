=begin rdoc
=== subclasses

Section::   used to group pages together with a same 'section_id'
Tag::       used to create collections of items.
Document::  contains data from uploaded files.
Image::     subclass of Document, contains image data that can be resized/viewed in the browser.
TextDocument::  subclass of Document, used by documents that can be edited online (scripts, text).
Template::  subclass of TextDocument. Contains the zafu code to make the look and feel of the site.
Skin::      subclass of Template. Contains other templates. The skin name must be unique throughout the site as it is used to identify the 'theme' of the site or parts of the site.
=end
class Page < Node
  before_validation :update_base_path #, :if => 'custom_base.changed?'

  # url base path. If a node is in 'projects' and projects has custom_base set, the
  # node's basepath becomes 'projects', so the url will be 'projects/node34.html'.
  # The basepath is cached. If rebuild is set to true, the cache is updated.
  def basepath(rebuild=false, update = true)
    if !self[:basepath] || rebuild
      if self[:custom_base]
        self.basepath = fullpath(rebuild, update)
        # FIXME: REMOVE this UPDATE !
        self.connection.execute "UPDATE #{self.class.table_name} SET basepath=#{Node.connection.quote(self.basepath)} WHERE id='#{self[:id]}'" if !new_record? && update && self.basepath_changed?
      else
        super
      end
    end
    self[:basepath]
  end

  private
    def update_base_path
      self[:basepath] = self.basepath(true)
    end

    def validate_node
      super

      # we are in a scope, we cannot just use the normal validates_...
      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      test_same_name = nil
      Node.send(:with_exclusive_scope) do
        if new_record?
          cond = ["name = ? AND parent_id = ? AND kpath LIKE 'NP%'",              self[:name], self[:parent_id]]
        else
          cond = ["name = ? AND parent_id = ? AND kpath LIKE 'NP%' AND id != ? ", self[:name], self[:parent_id], self[:id]]
        end
        test_same_name = Node.find(:all, :conditions=>cond)
      end
      errors.add("name", "has already been taken") unless test_same_name == []
    end

end