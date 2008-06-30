class Relation < ActiveRecord::Base
  validate        :valid_relation
  attr_accessor   :side, :link_errors, :start, :link
  attr_protected  :site_id
  has_many        :links, :dependent => :destroy
  
  # FIXME: validate uniqueness of source_role and target_role in scope site_id
  # FIXME: set kpath from class
  
  class << self
    
    # Open a relation to a role. start => 'role'
    def find_by_role(role)
      rel = find(:first, :conditions => ["(source_role = ? OR target_role = ?) AND site_id = ?", role, role, current_site[:id]])
      return nil unless rel
      if rel.target_role == role
        rel.side = :source
      else
        rel.side = :target
      end
      rel
    end
    
    # Find a relation by it's role, making sure the class path is compatible with the one given as parameter. If you define
    # a relation with a source role of 'news' which can only be linked to 'NPP%' class paths, doing 
    # find_by_role_and_kpath('news', 'NPP') will succeed but find_by_role_and_kpath('news', 'NNP') will fail returning nil.
    def find_by_role_and_kpath(role, kpath)
      rel = find_by_role(role)
      if rel && kpath =~ /\A#{rel.this_kpath}/
        rel
      else
        # invalid relation for the given class path
        nil
      end
    end
    
    def find_by_id(id)
      find(:first, :conditions => ["id = ? AND site_id = ?", id, current_site[:id]])
    end
  end   
  
  # Used by relation_links
  def records(options={})
    return @records if defined? @records
    opts = { :select     => "nodes.*,links.id AS link_id, links.status AS l_status, links.comment AS l_comment", 
             :joins      => "INNER JOIN links ON nodes.id=links.#{other_side} AND links.relation_id = #{self[:id]} AND links.#{link_side} = #{@start[:id]}",
             :group      => 'nodes.id'}
    
    [:order, :limit, :conditions].each do |sym|
      opts[sym] = options[sym] if options[sym]
    end
      
    @records = secure(Node) { Node.find(:all, opts) }
  end
  
  # I do not think this method is used anymore (all is done by @node.find(...)).
  def record(options={})
    return @record if defined?(@record) || @start.new_record?
    opts = { :select     => "nodes.*,links.id AS link_id, links.status AS l_status, links.comment AS l_comment", 
             :joins      => "INNER JOIN links ON nodes.id=links.#{other_side} AND links.relation_id = #{self[:id]} AND links.#{link_side} = #{@start[:id]}",
             :group      => 'nodes.id'}
    
    # limit overwritten options to 'order', 'limit' in case this method is used with unsafe parameters from the web.
    [:order].each do |sym|
      opts[sym] = options[sym] if options[sym]
    end
      
    @record = secure(Node) { Node.find(:first, opts) }
  end
  
  # Define the caller's side. Changes the relation into a proxy so we can add/remove links. This sets the caller on the source side of the relation.
  def source=(start)
    @start = start
    @side  = :source
  end
  
  # Define the caller's side. Changes the relation into a proxy so we can add/remove links. This sets the caller on the target side of the relation.
  def target=(start)
    @start = start
    @side  = :target
  end
  
  def other_link
    other_links ? other_links[0] : nil
  end
  
  def other_id
    other_link ? other_link[other_side] : nil
  end
  
  def other_ids
    (other_links || []).map { |l| l[other_side] }
  end
  
  def other_zip
    record ? record[:zip] : nil
  end
  
  def other_zips
    (records || []).map { |r| r[:zip] }
  end
  
  def other_role
    @side == :source ? target_role : source_role
  end
  
  def other_icon
    @side == :source ? target_icon : source_icon
  end
  
  def this_kpath
    @side == :source ? source_kpath : target_kpath
  end
  
  def other_kpath
    @side == :source ? target_kpath : source_kpath
  end
  
  def new_value=(values)
    if values.kind_of?(Array)
      if values[0].kind_of?(Hash)
        @new_value = values
      else
        @new_value = values.map {|v| {:id => v}}
      end
    elsif values.kind_of?(Hash)
      @new_value = [values]
    else
      @new_value = {:id => values}
    end
  end
  
  def new_value
    @new_value
  end
  
  def <<(rel_def)
    @new_value ||= other_links.map{|r| {:id => r[other_side], :status => r[:status], :comment => r[:comment]}}
    rel_def = {:id => rel_def} unless rel_def.kind_of?(Hash)
    @new_value << rel_def
  end
  
  def delete(obj_id)
    @new_value ||= other_links.map{|r| {:id => r[other_side], :status => r[:status], :comment => r[:comment]}}
    @new_value.reject!{|r| r[:id] == obj_id.to_i}
  end
  
  # find the links from the current context (source or target)
  def other_links
    @links ||= Link.find(:all, :conditions => ["relation_id = ? AND #{link_side} = ?", self[:id], @start[:id]])
  end
  
  # link can be changed if user can write in old and new
  # 1. can remove old link
  # 2. can write in new target
  def links_valid?
    @link_errors = []
    @link_values = {}
    if unique? && @new_value.size > 1
      # force unique value (keep last value)
      [@new_value.last]
    else
      @new_value
    end.each do |v|
      next if v[:id].blank?
      @link_values[v[:id].to_i] = v
    end
    
    # what changed ?
    @add_links    = @link_values.keys
    @del_links    = []
    @update_links = []
    # find all current links
    other_links.each do |link|
      obj_id = link[other_side]
      if value = @link_values[obj_id]
        @add_links.delete(obj_id) # ignore existing links
        
        if @link_values[obj_id] && @link_values[obj_id].size > 1
          link[:status]  = @link_values[obj_id][:status]
          link[:comment] = @link_values[obj_id][:comment]
          @update_links << link
        end
      else
        @del_links << link
      end
      
    end
    
    # 2. can write in new target ? (and remove targets previous link)
    @add_links.each do |obj_id|
      if target = find_target(obj_id)
        # make sure we can overwrite previous link if as_unique
        if as_unique?
          if previous_link = Link.find(:first, :conditions => ["relation_id = ? AND #{other_side} = ?", self[:id], target[:id]])
            @del_links << previous_link
          end
        end
      else
        @link_errors << 'invalid target'
      end
    end
    
    # 1. can remove old link ?
    @del_links.each do |link|
      unless find_node(link[other_side], unique?)
        @link_errors << 'cannot remove link'
      end
    end
    
    return @link_errors == []
  end

  def update_links!
    return unless @del_links && @add_links
    @del_links.each { |l| l.destroy }
    @update_links.each { |l| l.save }
    
    return if @add_links == []
    list = []
    @add_links.each do |obj_id| 
      v = @link_values[obj_id]
      list << "(#{self[:id]},#{@start[:id]},#{obj_id},#{Link.connection.quote(v[:status])},#{Link.connection.quote(v[:comment])})"
    end
    Link.connection.execute "INSERT INTO links (`relation_id`,`#{link_side}`,`#{other_side}`,`status`,`comment`) VALUES #{list.join(',')}"
    remove_instance_variable(:@links)
  end
  
  def unique?
    @side == :source ? target_unique : source_unique
  end
  
  def as_unique?
    @side == :source ? source_unique : target_unique
  end
  
  def source_unique
    self[:source_unique] ? true : false
  end
  
  def target_unique
    self[:target_unique] ? true : false
  end
  
  def link_side
    @side == :source ? 'source_id' : 'target_id'
  end
  
  def other_side
    @side == :source ? 'target_id' : 'source_id'
  end
  
  private
    def valid_relation
      unless visitor.is_admin?
        errors.add('base', 'you do not have the rights to do this')
        return false
      end
      self[:site_id] = current_site[:id]
    end
    
    def relation_class
      @start.relation_base_class
    end
    
    def find_node(obj_id, unique)
      unique ? secure_drive(Node) { Node.find_by_id(obj_id) } : secure_write(Node) { Node.find_by_id(obj_id) }
    end
    
    def find_target(obj_id)
      if as_unique?
        secure_drive(relation_class) { relation_class.find(:first, :conditions=>['id = ? AND kpath LIKE ?', obj_id, "#{other_kpath}%"]) }
      else
        secure_write(relation_class) { relation_class.find(:first, :conditions=>['id = ? AND kpath LIKE ?', obj_id, "#{other_kpath}%"]) }
      end
    end

end
