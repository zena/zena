=begin rdoc
=== subclasses

Section::   used to group pages together with a same 'section_id'
Tag::       used to create collections of items.
Document::  contains data from uploaded files.
Image::     subclass of Document, contains image data that can be resized/viewed in the browser.
TextDocument::  subclass of Document, used by documents that can be edited online (scripts, text).
Template::  subclass of TextDocument. Contains the zafu code to make the look and feel of the site.
Skin::      subclass of Template. Contains other templates.
=end
class Page < Node

  private

    def validate_node
      super

      # we are in a scope, we cannot just use the normal validates_...
      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      test_same_name = nil
      if prop.title_changed? || parent_id_changed? || kpath_changed?
        Node.send(:with_exclusive_scope) do
          if !new_record?
            cond = ['id != ?', id]
          else
            cond = nil
          end
          test_same_name = Node.find_by_parent_title_and_kpath(parent_id, title, 'NP')
        end
        errors.add("title", "has already been taken") if test_same_name
      end
    end

end