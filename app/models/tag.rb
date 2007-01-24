=begin rdoc
=== Read/Write for a tag
Users can add nodes to a tag collection, if they have *write access* to the #Tag. It is exactly the same as adding a
sub page or a document. See #Link for more details.
=end
class Tag < Page
  link :tag_for, :class_name=>'Node', :as=>'tag', :collector=>true
  
  def pages
    @pages ||= tag_for(:conditions=>"kpath NOT LIKE 'NPD%'", :or=>["parent_id = ?", self[:id]])
  end
  
  def documents
    @documents ||= tag_for(:conditions=>"kpath LIKE 'NPD%'", :or=>["parent_id = ?", self[:id]])
  end
end