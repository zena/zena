=begin rdoc
A DataEntry stores unversioned information across 4 nodes. The main purpose of this data is to
store simple statistical values, registrations or other kinds of lists with nodes.

A data entry has four links to nodes (node_a, node_b, node_c, node_d) and 'nodes' (all four links). On the other side of the link, the node has four links to data sets (data_a, data_b, data_c, data_d) and 'data' (all four data sets).

The choice of four links is related to simple seizure situations that require up to four relations. For example a time invoicing utility would require 'contact' (who did the job), 'project' and 'invoice' (if billed). An accounting system would require 'from' (who paid), 'for' (budget position), 'credit' and 'debit'.

DataEntries are signed with 'creation date', 'modification date' and 'user_id'.

A visitor needs write access in all nodes the data should link to. A visitor also needs write access to the old node to remove a link to that node.

A visitor can edit a data entry if he/she has write access to the reference node (node_a).
=end
class DataEntry < ActiveRecord::Base
  attr_public  :created_at, :updated_at, :date, :text, :value, :value_a, :value_b, :node_a_zip, :node_b_zip, :node_c_zip, :node_d_zip
  attr_protected :site_id
  zafu_context  :node_a => "Node", :node_b => "Node", :node_c => "Node", :node_d => "Node", :nodes => ["Node"], :author => "Contact", :user => "User"
  NodeLinkSymbols   = [:node_a,    :node_b,    :node_c,    :node_d]
  NodeLinkSymbolsId = [:node_a_id, :node_b_id, :node_c_id, :node_d_id]
  validate    :valid_data_entry
  before_save :sign_data
  belongs_to  :user
  
  # Create a new DataEntry from attributes given by the mean wild web.
  def self.create_data_entry(attributes)
    return create(transform_attributes(attributes))
  end
  
  # modify attributes so ext sees 'zip' values but we store 'ids'
  def self.transform_attributes(new_attributes)
    attributes = new_attributes.stringify_keys
    
    attributes.keys.each do |key|
      if key == 'date'
        attributes[key] = attributes[key].to_utc(_('datetime'), visitor.tz)
      elsif key =~ /^(\w+)_id$/
        if key[0..4] == 'node_'
          attributes[key] = Node.translate_pseudo_id(attributes[key]) || attributes[key]
        else
          attributes[key] = Node.translate_pseudo_id(attributes[key]) || attributes[key]
        end
      elsif key == 'text'
        # translate zazen
        value = attributes[key]
        if value.kind_of?(String)
          attributes[key] = ZazenParser.new(value,:helper=>self, :node=>self).render(:translate_ids=>:zip)
        end
      end
    end
    
    attributes
  end
  
  NodeLinkSymbols.each do |sym|
    class_eval "def #{sym}
      return nil unless self[:#{sym}_id]
      @#{sym} ||= secure(Node) { Node.find_by_id(self[:#{sym}_id]) }
    end
    
    def #{sym}_zip
      #{sym} ? #{sym}.zip : nil
    end
    "
  end
  
  
  # 'value' is an alias for 'value_a'
  def value
    self[:value_a]
  end
  
  def value=(v)
    self.value_a = v
  end
  
  def author
    user.contact
  end
  
  def nodes
    ids = NodeLinkSymbolsId.map { |s| self[s] }.compact.uniq
    secure!(Node) { Node.find(:all, :conditions => "id IN ('#{ids.join("','")}')") }
  end
  
  def ref_node
    @ref_node ||= node_a
  end
  
  # Update a data entry's attributes, transforming the attributes first from the visitor's context to internal context.
  def update_attributes_with_transformation(new_attributes)
    update_attributes(DataEntry.transform_attributes(new_attributes))
  end
  
  def clone
    new_ent = DataEntry.new
    NodeLinkSymbols.each do |sym|
      sym_id = "#{sym}_id"
      new_ent[sym_id] = self[sym_id] # copy relation information
    end
    new_ent
  end
  
  # needed by zafu for ajaxy stuff
  def zip
    self[:id]
  end
  
  def can_write?
    ref_node.can_write?
  rescue
    nil
  end
  
  private
    # make sure all new/deleted node relations are allowed (write access)
    def valid_data_entry
      link_count = 0
      DataEntry::NodeLinkSymbols.each do |sym|
        sym_id = "#{sym}_id".to_sym
        link_count += 1 if self[sym_id]
        validate_node_link(sym_id)
      end
      errors.add("base", "a data entry must link to at least one node") if link_count == 0
    end
    
    # sign changes before saving
    def sign_data
      self[:user_id] = visitor[:id]
      self[:site_id] = visitor.site[:id]
    end
    
    def validate_node_link(sym)
      if new_record?
      elsif self[sym] == old[sym]
        return
      else
        # id changed
        # make sure we can write in old (need write access to remove a relation)
        if !old[sym].nil? && !secure_write(Node) { Node.find_by_id(old[sym]) }
          errors.add(sym, "cannot remove old relation")
        end
      end
      # check new link
      if !self[sym].nil? && !secure_write(Node) { Node.find_by_id(self[sym]) }
        errors.add(sym, "invalid node")
      end
    end
    
    def old
      @old ||= DataEntry.find(self[:id])
    end
end
