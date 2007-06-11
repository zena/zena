class Relation < ActiveRecord::Base
  validate      :valid_relation
  attr_accessor :source, :target, :link_errors, :new_value

  def records(options={})
    
    conditions = options.delete(:conditions)
    direction  = options.delete(:direction)

    # :from
    side_cond = "links.relation_id = ?"
    params    = [self[:id]]
    case options[:from]
    when 'site'  
      count = :all
    when 'section'
      if conditions.kind_of?(Array)
        conditions[0] = "(#{conditions[0]}) AND section_id = ?"
        conditions << start[:section_id]
      elsif conditions
        conditions = ["(#{conditions}) AND section_id = ?", start[:section_id]]
      else
        conditions = ["section_id = ?", start[:section_id]]
      end
      count = :all
    when 'project'
      if conditions.kind_of?(Array)
        conditions[0] = "(#{conditions[0]}) AND project_id = ?"
        conditions << start[:project_id]
      elsif conditions
        conditions = ["(#{conditions}) AND project_id = ?", start[:project_id]]
      else
        conditions = ["project_id = ?", start[:project_id]]
      end
      count = :all
    else
      count = if @source
          target_unique ? :first : :all
        else
          source_unique ? :first : :all
        end
        
      if direction == 'both'
        side_cond << " AND (links.#{link_side} = ? OR links.#{other_side} = ?) AND (nodes.id <> ? OR links.#{other_side} = links.#{link_side})"
        params += [start[:id]] * 3
      else
        side_cond << " AND links.#{link_side} = ?"
        params += [start[:id]]
      end
    end
    options.delete(:from)

    if direction == 'both'
      join_direction = "(nodes.id=links.#{other_side} OR nodes.id=links.#{link_side})"
    else
      join_direction = "nodes.id=links.#{other_side}"
    end

    if options[:or]
      join = 'LEFT'
      if options[:or].kind_of?(Array)
        or_clause = options[:or].shift
        params.unshift(options[:or])
      else
        or_clause = options[:or]
      end  
      inner_conditions = ["(#{or_clause}) OR (#{side_cond})", *params ]
      options.delete(:or)
    else
      join = 'INNER'
      inner_conditions = ["#{side_cond}", *params ]
    end
    options.merge!( :select     => "nodes.*, links.id AS link_id", 
                    :joins      => "#{join} JOIN links ON #{join_direction}",
                    :conditions => inner_conditions,
                    :group      => 'nodes.id'
                    )
    
    if conditions
      Node.with_scope(:find=>{:conditions=>conditions}) do
        secure(Node) { Node.find(count, options ) }
      end
    else
      secure(Node) { Node.find(count, options ) }
    end
  end

  def <<(obj_id)
    @new_value ||= links.map{|r| r[other_side]}
    @new_value << obj_id.to_i
  end
  
  def delete(obj_id)
    @new_value ||= links.map{|r| r[other_side]}
    @new_value.delete(obj_id.to_i)
  end
  
  # find the links from the current context (source or target)
  def links
    @links ||= Link.find(:all, :conditions => ["relation_id = ? AND #{link_side} = ?", self[:id], start[:id]])
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
    links.each do |link|
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
    list = @add_ids.map {|obj_id| "(#{self[:id]},#{start[:id]},#{obj_id})"}.join(',')
    Link.connection.execute "INSERT INTO links (`relation_id`,`#{link_side}`,`#{other_side}`) VALUES #{list}"
  end
  
  private
    def valid_relation
      unless visitor.is_admin?
        errors.add('base', 'you do not have the rights to do this')
        return false
      end
    end
  
    def unique?
      @source ? target_unique : source_unique
    end
    
    def as_unique?
      @source ? source_unique : target_unique
    end
    
    def link_side
      @source ? 'source_id' : 'target_id'
    end
    
    def other_side
      @source ? 'target_id' : 'source_id'
    end
    
    def start
      @source || @target
    end
    
    def relation_class
      start.relation_base_class
    end
    
    def find_target(obj_id)
      if as_unique?
        secure_drive(relation_class) { relation_class.find(obj_id) }
      else
        secure_write(relation_class) { relation_class.find(obj_id) }
      end
    end

end
