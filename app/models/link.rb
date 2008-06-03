class Link < ActiveRecord::Base
  attr_reader :relation
  
  class << self
    def find_through(node, link_id)
      link = Link.find(:first, :conditions => ['(source_id = ? OR target_id = ?) AND id = ?', node[:id], node[:id], link_id])
      link.set_caller(node)
      link
    end
  end
  
  def update_attributes_with_transformations(attrs)
    attributes = attrs.dup
    ['role', 'status', 'comment', 'other_zip'].each do |k|
      self[k] = attributes[k] = attrs[k].blank? ? nil : attrs[k]
    end
    
    other_id = secure(Node) {Node.translate_pseudo_id(attrs['other_zip'])}
    # ALL THIS IS BAD. Bad design lead to bad hacky code. PLEASE rewrite links !
    @node.update_link(attrs['role'], :id => other_id, :status => attributes['status'], :comment => attributes['comment'])
    @node.save
    if @other == @target
      self[:target_id] = other_id
      self[:id] = Link.find(:first, :conditions => ['target_id = ? AND relation_id = ?', other_id, relation_id])[:id] 
      @target = nil
    else
      self[:source_id] = other_id
      self[:id] = Link.find(:first, :conditions => ['source_id = ? AND relation_id = ?', other_id, relation_id])[:id]
      @source = nil
    end
    sync_node
    @errors = @node.errors
  end
  
  def target
    @target ||= secure!(Node) { Node.find(target_id) }
  end
  
  def source
    @source ||= secure!(Node) { Node.find(source_id) }
  end
  
  def set_caller(node)
    @node = node
    @relation    = @node.relation_proxy(:link => self)
    self['role'] = @relation.other_role
    sync_node
  end
  
  def other
    @other
  end
  
  def other_zip
    self['other_zip']
  end
  
  def node_zip
    self['node_zip']
  end
  
  private
    def sync_node
      if source_id == @node[:id]
        @other = target
      else
        @other = source
      end
      self['node_zip']  = @node[:zip]
      self['other_zip'] = @other.zip
      @other['link_id'] = self[:id]
      @other.link  = self # used to get l_status, l_comment after save
      
      @node['link_id']   = self[:id]
      @node['l_status']  = self[:status]
      @node['l_comment'] = self[:comment]
    end
end
