class RelationProxy < Relation
  attr_accessor   :side, :link_errors, :start, :other_link
  
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
    
    # Find a relation proxy for a role through a given node.
    # The finder makes sure the class path is compatible with the node's class/virtual_class given as parameter.
    def get_proxy(node, role)
      rel = find_by_role(role)
      if rel && (node.new_record? || node.vclass.kpath =~ /\A#{rel.this_kpath}/)
        rel.start = node
        rel
      else
        # invalid relation for the given class path
        nil
      end
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
  
  # When a ...-to-many node is loaded and we modify it, focus on this specific node. For example:
  # calendar_status does not make sense (there can be many calendars). But if we focus on a specific
  # calendar, we then get the status for this particular link.
  def other_link=(link)
    return unless link[:relation_id] == self[:id]
    @other_link = link
  end
  
  # get
  
  def other_link
    other_links ? other_links[0] : nil
  end
  
  def other_id
    other_link ? other_link[other_side] : nil
  end
  
  def other_zip
    record ? record[:zip] : nil
  end
  
  def other_ids
    (other_links || []).map { |l| l[other_side] }
  end
  
  def other_zips
    (records || []).map { |r| r[:zip] }
  end
  
  def other_status
    other_link ? other_link[:status] : nil
  end
  
  def other_comment
    other_link ? other_link[:comment] : nil
  end
  
  def other_role
    @side == :source ? target_role : source_role
  end

  def this_role
    @side == :source ? source_role : target_role
  end
  
  def other_icon
    @side == :source ? target_icon : source_icon
  end
  
  # set
  
  def other_id=(v)
    attributes_to_update[:id] = v.kind_of?(Array) ? v.uniq.compact.map {|v| v.to_i} : (v.blank? ? nil : v.to_i)
  end
  
  def other_ids=(v)
    self.other_id = v
  end
  
  def remove_link(link)
    @links_to_delete ||= []
    @links_to_delete << link
  end
  
  def other_status=(v)
    attributes_to_update[:status] = v.blank? ? nil : v
  end
  
  def other_comment=(v)
    attributes_to_update[:comment] = v.blank? ? nil : v
  end
  
  def this_kpath
    @side == :source ? source_kpath : target_kpath
  end
  
  def other_kpath
    @side == :source ? target_kpath : source_kpath
  end
  
  # find the links from the current context (source or target)
  def other_links
    @other_links ||= Link.find(:all, :conditions => ["relation_id = ? AND #{link_side} = ?", self[:id], @start[:id]])
  end
  
  # link can be changed if user can write in old and new
  # 1. can remove old link
  # 2. can write in new target
  def attributes_to_update_valid?
    debugger if $debbbb
    return true unless @attributes_to_update || @links_to_delete
    
    @link_errors  = []
    @add_links    = []
    @del_links    = []
    @update_links = []
    
    if @links_to_delete
      # only removing links
      @del_links = @links_to_delete
      @attributes_to_update = {}
    else
      # check if we have an update/create
      unless @attributes_to_update[:id]
        # try to find current id/ids
        if @other_link
          @attributes_to_update[:id] = @other_link[other_side]
        elsif link_id = @start.link_id
          @other_link = Link.find(link_id)
          @attributes_to_update[:id] = @other_link[other_side]
        elsif unique?
          if other_id
            @attributes_to_update[:id] = other_id
          elsif @attributes_to_update.keys == [:id]
            # ignore (set icon_id = nil when already == nil)
          else
            @link_errors << "invalid target"
          end
        else
          # error: cannot set other attributes (status/comment) on multiple nodes
          @link_errors << "invalid target"
        end
      end
    
      if @attributes_to_update[:id].kind_of?(Array) 
        if unique?
          @link_errors << "Cannot set multiple targets on #{as_unique? ? 'one' : 'many'}-to-one relation '#{this_role}'."
        elsif @attributes_to_update.has_key?(:status) || @attributes_to_update.has_key?(:comment)
          keys = @attributes_to_update.keys
          keys.delete(:id)
          @link_errors << "Cannot set attributes #{keys.join(', ')} on multiple targets."
        end
      end
    
      return false if @link_errors != []
    
      # 1. find what changed
      if @attributes_to_update[:id].kind_of?(Array)
        # ..-to-many
        # define all links
      
        # list of link ids set
        add_link_ids = @attributes_to_update[:id]

        # find all current links
        other_links.each do |link|
          obj_id = link[other_side]
          if add_link_ids.include?(obj_id)
            # ignore existing links
            add_link_ids.delete(obj_id)
          else
            # remove unused links
            @del_links << link
          end
        end  
        @add_links = add_link_ids.map {|obj_id| Hash[:id,obj_id] }
      elsif unique?
        # ..-to-one
        # define/update link
        if other_id == @attributes_to_update[:id]
          # same target: update
          @update_links << changed_link(other_link, @attributes_to_update)
        else
          # other target: replace
          @del_links = [other_link] if other_link
          @add_links << @attributes_to_update
        end
      else
        # ..-to-many
        # add/update a link
        if other_ids.include?(@attributes_to_update[:id])
          # update
          if @attributes_to_update.has_key?(:status) || @attributes_to_update.has_key?(:comment)
            other_links.each do |link|
              if link[other_side] == @attributes_to_update[:id]
                @update_links << changed_link(link, @attributes_to_update)
                break
              end
            end
          end
        else
          # add
          @add_links << @attributes_to_update
        end
      end  
    end
    
    # 2. can write in new target ? (and remove targets previous link)
    @add_links.each do |hash|
      if target = find_target(hash[:id])
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
    
    @update_links.compact!
    return @link_errors == []
  end
  
  # Return updated link if changed or nil when nothing changed
  def changed_link(link, attrs)
    changed = false
    [:status, :comment].each do |sym|
      next unless attrs.has_key?(sym)
      if attrs[sym] != link[sym]
        changed = true
        link[sym] = attrs[sym]
      end
    end
    changed ? link : nil
  end

  def update_links!
    return unless @attributes_to_update
    @del_links.each    { |l| l.destroy }
    @update_links.each { |l| l.save }
    
    return if @add_links == []
    
    list = []
    @add_links.each do |hash|
      next unless hash[:id]
      list << "(#{self[:id]},#{@start[:id]},#{hash[:id]},#{Link.connection.quote(hash[:status])},#{Link.connection.quote(hash[:comment])})"
    end
    Link.connection.execute "INSERT INTO links (`relation_id`,`#{link_side}`,`#{other_side}`,`status`,`comment`) VALUES #{list.join(',')}"
    @attributes_to_update = nil
    @links_to_delete      = nil
    remove_instance_variable(:@records)     if defined?(@records)
    remove_instance_variable(:@record)      if defined?(@record)
    remove_instance_variable(:@other_links) if defined?(@other_links)
  end
  
  def unique?
    @side == :source ? target_unique : source_unique
  end
  
  def as_unique?
    @side == :source ? source_unique : target_unique
  end
  
  # def source_unique
  #   self[:source_unique] ? true : false
  # end
  # 
  # def target_unique
  #   self[:target_unique] ? true : false
  # end
  
  def link_side
    @side == :source ? 'source_id' : 'target_id'
  end
  
  def other_side
    @side == :source ? 'target_id' : 'source_id'
  end
  
  private
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
    
    def attributes_to_update
      @attributes_to_update ||= {}
    end
end
