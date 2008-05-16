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
    
    other_id = Node.translate_pseudo_id(attrs['other_zip'])

    @node.update_link(attrs['role'], :id => other_id, :status => attributes['status'], :comment => attributes['comment'])
    @node.save
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
    self['node_zip'] = node[:zip]
    if source_id = node[:id]
      self['other_zip'] = target.zip
    else
      self['other_zip'] = source.zip
    end
    @relation    = @node.relation_proxy(:link => self)
    self['role'] = @relation.other_role
    sync_node
  end
  
  private
    def sync_node
      @node['link_id']   = self[:id]
      @node['l_status']  = self[:status]
      @node['l_comment'] = self[:comment]
    end
end
