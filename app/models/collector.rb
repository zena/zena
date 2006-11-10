=begin rdoc
=== Read/Write for a collector
Users can add items to a collection, if they have *write access* to the #Collector. It is exactly the same as adding a
sub page or a document.
=end

class Collector < Page
  has_and_belongs_to_many :items, :join_table=>'links', :foreign_key=>'parent_id', :association_foreign_key=>'item_id', :conditions=>"role='collected'"
  def find_in_collection(*args)
    secure(Item) { items.find(*args) }
  end
  
  # Find all sub-pages (All but documents)
  def pages
    return @pages if @pages
    children ||= secure(Page) { 
      Page.find(:all, :order=>'name ASC', :conditions=>["parent_id = ? AND kpath NOT LIKE 'IPD%'", self[:id] ]) } || []
    @pages = children + secure(Item) { items.find(:all) }
    @pages.sort! {|a,b| a.name <=> b.name}
    @pages
  end
end
