class Relation < ActiveRecord::Base
  validate        :valid_relation
  attr_accessor   :side, :link_errors, :start, :new_value
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
  
  def records(opts={})
    return @records if defined? @records
    
    base_condition = "links.relation_id = #{self[:id]} AND links.#{link_side} = #{@start[:id]}"
    
    if cond = opts[:conditions]
      if cond.kind_of?(Array)
        opts[:conditions] = ["(#{cond[0]}) AND (#{base_condition})"] + cond[1..-1]
      else
        opts[:conditions] = "(#{cond}) AND (#{base_condition})"
      end
    end
    
    options = Node.clean_options(opts).merge( 
                    :select     => "nodes.*, links.id AS link_id", 
                    :joins      => "INNER JOIN links ON nodes.id=links.#{other_side}",
                    :group      => 'nodes.id'
                    )
    @records = secure(Node) { Node.find(:all, options) }
  rescue ActiveRecord::RecordNotFound
    @records = nil
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
  
  def <<(obj_id)
    @new_value ||= other_links.map{|r| r[other_side]}
    @new_value << obj_id.to_i
  end
  
  def delete(obj_id)
    @new_value ||= other_links.map{|r| r[other_side]}
    @new_value.delete(obj_id.to_i)
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
    if unique?
      if @new_value.kind_of?(Array)
        if @new_value.size > 1
          @link_errors << 'should be a unique value'
          return false
        else
          values = @new_value
        end
      else
        values = [@new_value]
      end
    else
      unless @new_value.kind_of?(Array)
        @link_errors << 'should be an array of ids'
        return false
      end
      values = @new_value
    end
    values.map!{|i| i.to_i }
    
    # what changed ?
    @add_ids   = values
    @del_links = []
    # find all current links
    other_links.each do |link|
      obj_id = link[other_side]
      unless @add_ids.include?(obj_id)
        @del_links << link
      end
      @add_ids.delete(obj_id) # ignore existing links
    end
    
    # 1. can remove old link ?
    @del_links.each do |link|
      begin
        find_target(link[other_side])
      rescue ActiveRecord::RecordNotFound
        @link_errors << 'cannot remove link'
      end
    end
    
    # 2. can write in new target ?
    @add_ids.each do |obj_id|
      begin
        find_target(obj_id)
      rescue ActiveRecord::RecordNotFound
        @link_errors << 'invalid target'
      end
    end
    return @link_errors == []
  end

  def update_links!
    return unless @del_links && @add_ids
    @del_links.each { |l| l.destroy }
    return if @add_ids == []
    list = @add_ids.map {|obj_id| "(#{self[:id]},#{@start[:id]},#{obj_id})"}.join(',')
    Link.connection.execute "INSERT INTO links (`relation_id`,`#{link_side}`,`#{other_side}`) VALUES #{list}"
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
    
    def find_target(obj_id)
      if as_unique?
        secure_drive(relation_class) { relation_class.find(obj_id) }
      else
        secure_write(relation_class) { relation_class.find(obj_id) }
      end
    end

end
