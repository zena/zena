class Relation < ActiveRecord::Base
  attr_accessor :source, :target, :link_errors, :new_value
  
  unless method_defined?(:secure) || private_method_defined?(:secure)
    # define dummy 'secure' and 'secure_write' to work out of Zena
    class_eval "def secure(*args); yield; end"
    class_eval "def secure_write(*args); yield; end"
    class_eval "def secure_drive(*args); yield; end"
  end
  
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
  def valid?
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
=begin
  # Look at Zena::Acts::Linkable for documentation.
  def link(method, options={})
    method = method.to_s
    unless method_defined?(:secure) || private_method_defined?(:secure)
      # define dummy 'secure' and 'secure_write' to work out of Zena
      class_eval "def secure(*args); yield; end"
      class_eval "def secure_write(*args); yield; end"
    end
    @@roles_for_class[self] ||= {}
    class_name = options[:class_name] || method.singularize.capitalize
    if options[:for] || options[:as]
      link_side  = 'target_id'
      other_side = 'source_id'
    else
      link_side  = 'source_id'
      other_side = 'target_id'
    end
    if options[:unique]
      count = :first
      role = (options[:as] || method.downcase).to_s
    else
      count = :all
      role = (options[:as] || method.downcase.singularize).to_s
    end
    link_def = { :method=>method, :role=>role, :link_side=>link_side, :other_side=>other_side, :unique=>(options[:unique] == true), :collector=>(options[:collector] == true), :class=>class_name, :count=>count }
    
    @@roles_for_class[self][method] = link_def
    @@defined_role[method] = link_def
    finder = <<-END
      def #{method}(options={})
        fetch_link(#{method.inspect}, options)
      end
    END
    class_eval finder
    unless method_defined?(:destroy_links) || private_method_defined?(:destroy_links)
      after_destroy :destroy_links
      class_eval <<-END
        def destroy_links
          self.class.connection.execute("DELETE FROM links WHERE source_id = \#{self[:id]} OR target_id = \#{self[:id]}")
        end
      END
    end
    
    if options[:as_unique]
      destroy_if_as_unique     = <<-END
      if link2 = Link.find_by_role_and_#{other_side}('#{role}', obj_id)
        errors.add('#{role}', 'can not destroy') unless link2.destroy
      end
      END
      find_target = 'secure_drive'
    else
      destroy_if_as_unique = ""
      find_target = 'secure_write'
    end
    
    if options[:unique]
      methods = <<-END
        def #{method}_id=(obj_id); @#{method}_id = obj_id; end
        def #{method}=(obj); @#{method}_id = obj.id; end
        def #{method}_id
          link = Link.find_by_role_and_#{link_side}('#{role}', self[:id])
          link ? link[:#{other_side}] : nil
        end
        
        def #{method}_zip
          fetch_link(#{method.inspect})[:zip]
        end
        
        # link can be changed if user can write in old and new
        # 1. can remove old link
        # 2. can write in new target
        def validate_#{method}
          return unless defined? @#{method}_id
          
          # 1. can remove old link ?
          if link = Link.find_by_role_and_#{link_side}('#{role}', self[:id])
            obj_id = link.#{other_side}
            begin
              #{find_target}(#{class_name}) { #{class_name}.find(obj_id) }
            rescue
              errors.add('#{role}', 'cannot remove old link')
            end
          end
          
          # 2. can write in new target ?
          obj_id = @#{method}_id
          if obj_id && obj_id != ''
            # set
            begin
              #{find_target}(#{class_name}) { #{class_name}.find(obj_id) } # make sure we can write in the object
            rescue
              errors.add('#{role}', 'invalid')
            end
          end
        end
        
        def save_#{method}
          return unless defined? @#{method}_id
          obj_id = @#{method}_id
          if obj_id && obj_id != ''
            # set
            obj_id = obj_id.to_i
            if link = Link.find_by_role_and_#{link_side}('#{role}', self[:id])
              #{destroy_if_as_unique}
              link.#{other_side} = obj_id
            else
              #{destroy_if_as_unique}
              link = Link.new(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{role}")
            end  
            errors.add('#{role}', 'could not be set') unless link.save
          else
            # remove
            if link = Link.find_by_role_and_#{link_side}('#{role}', self[:id])
              errors.add('#{role}', 'could not be removed') unless link.destroy
            end
          end
          remove_instance_variable :@#{method}_id
          return errors.empty?
        end
      END
    else
      # multiple
      meth = method.singularize
      methods = <<-END
        def #{meth}_ids=(obj_ids)
          @#{meth}_ids = obj_ids ? obj_ids.map{|i| i.to_i} : []
        end
        # add a single element
        def #{meth}_id=(obj_id)
          @#{meth}_ids = #{meth}_ids + [obj_id]
        end
        def #{method}=(objs)
          @#{meth}_ids = objs ? objs.map{|obj| obj[:id]} : []
        end
        def #{meth}_ids; res = #{method}; res ? res.map{|r| r[:id]} : []; end
        def #{meth}_zips; res = #{method}; res ? res.map{|r| r[:zip]}.join(', ') : ''; end
        
        # link can be changed if user can write in old and new
        # 1. can remove old links
        # 2. can write in new targets
        def validate_#{method}
          return unless defined? @#{meth}_ids
          unless @#{meth}_ids.kind_of?(Array)
            errors.add('#{role}', 'bad format') 
            return false
          end
          # what changed ?
          obj_ids = @#{meth}_ids.map{|i| i.to_i }
          del_ids = []
          # find all current links
          (#{method} || []).each do |link|
            obj_id = link[:id]
            unless obj_ids.include?(obj_id)
              del_ids << obj_id
            end
            obj_ids.delete(obj_id) # ignore existing links
          end
          @#{meth}_add_ids = obj_ids
          @#{meth}_del_ids = del_ids
          
          # 1. can remove old link ?
          @#{meth}_del_ids.each do |obj_id|
            begin
              #{find_target}(#{class_name}) { #{class_name}.find(obj_id) }
            rescue
              errors.add('#{role}', 'cannot remove link')
            end
          end
          
          # 2. can write in new target ?
          @#{meth}_add_ids.each do |obj_id|
            begin
              #{find_target}(#{class_name}) { #{class_name}.find(obj_id) }
            rescue
              errors.add('#{meth}', 'invalid target')
            end
          end
          
        end
        
        def save_#{method}
          return true unless defined? @#{meth}_ids
          
          if @#{meth}_del_ids && (obj_ids = @#{meth}_del_ids) != []
            # remove all old links for this role
            links = Link.find(:all, :conditions => ["links.role='#{role}' AND links.#{link_side} = ? AND links.#{other_side} IN (\#{obj_ids.join(',')})", self[:id] ])
            links.each do |l|
              errors.add('#{role}', 'could not be removed') unless l.destroy
            end
          end
          
          if @#{meth}_add_ids && (obj_ids = @#{meth}_add_ids) != []
            # add new links for this role
            obj_ids.each do |obj_id|
              #{destroy_if_as_unique}
              errors.add('#{role}', 'could not be set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{role}")
            end
          end
          remove_instance_variable :@#{meth}_ids
          return errors.empty?
        end
        
        def remove_#{meth}(obj_id)
          @#{meth}_ids ||= #{meth}_ids || []
          # ignore bad obj_ids, just pass
          @#{meth}_ids.delete(obj_id.to_i)
          return true
        end
        
        def add_#{meth}(obj_id)
          @#{meth}_ids ||= #{meth}_ids || []
          @#{meth}_ids << obj_id.to_i unless @#{meth}_ids.include?(obj_id.to_i)
          return true
        end
        
        def #{method}_for_form(options={})
          options.merge!( :select     => "\#{#{class_name}.table_name}.*, links.id AS link_id, links.role", 
                          :joins      => "LEFT OUTER JOIN links ON \#{#{class_name}.table_name}.id=links.#{other_side} AND links.role='#{role}' AND links.#{link_side} = \#{self[:id].to_i}"
                          )
          #{find_target}(#{class_name}) { #{class_name}.find(:all, options) }
        rescue ActiveRecord::RecordNotFound
          []
        end
          
      END
    end
    class_eval methods
    validate     "validate_#{method}".to_sym
    after_save   "save_#{method}".to_sym
  end
=end
  private
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
