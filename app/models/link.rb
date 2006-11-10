class Link < ActiveRecord::Base
  belongs_to :parent, :foreign_key=>"parent_id", :class_name=>"Item"
  belongs_to :item
  
  def self.create(opt={})
    item   = opt[:item]
    parent = opt[:parent]
    role   = opt[:role]
    
    # does the link exist already ?
    link = Link.find_by_parent_id_and_item_id_and_role(parent[:id], item[:id], role)
    return nil if link
    return nil unless item.kind_of?(class_for_role(role))
    
    if super(:item_id=>item[:id], :parent_id=>parent[:id], :role=>role)
      item.role = role
      item
    else
      nil
    end
  end
  
  def self.roles_for_form
    roles = []
    roles << ['tag', 'tag']
    roles << ['icon', 'icon']
    roles
  end
  
  def self.class_for_role(role)
    case role.to_s
    when 'tag'
      Collector
    when 'icon'
      Image
    end
  end
end
