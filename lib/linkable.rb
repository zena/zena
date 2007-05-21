module Zena
  module Acts
=begin rdoc
Linkable provides the 'link' macro.

This macro works with a 'links' table with 'role', 'source_id' and 'target_id' fields (plus 'id' auto increment). With this
set, you can create 'roles' between objects. For example if you have a class Person, you could add
  class Person < ActiveRecord::Base
    link :wife,    :class_name=>'Person', :unique=>true, :as_unique=>true
    link :husband, :class_name=>'Person', :unique=>true, :as=>'wife', :as_unique=>true
  end

This creates the following methods for your Person objects:
  @john.wife                   ==> finds wife
  @mary.husband                ==> find husband
  @john.wife = @mary           ==> set wife
  @john.wife_id = @mary.id     ==> set wife by id
  @mary.husband = @john        ==> set husband
  @mary.husband_id = @john.id  ==> set husband by id
  
Because of the ":as" clause, 'husbands' and 'wifes' are related together, so
  @john.wife = @mary   ==> @mary.husband gives @john

The ":unique" and ":as_unique" clauses make sure @john has only one wife and @mary has only one husband

Another example with the infamous 'tags'
  class Post < ActiveRecord::Base
    link :tags, :class_name=>'Tag'
  end

  class Tag < ActiveRecord::Base
    link :posts, :class_name=>'Post', :as=>'tag'
  end

This gives the posts the following methods:
@post.tags          ==> list of tags
This is a finder. It can be used as @post.tags(:conditions=>...). There is an additional option
for an 'OR' clause in case you need to 'merge' linked objects with direct children. Example :
  @post.tags(:or=>["parent_id = ?", self[:id]]) # this does a single call, so ':order, :limit' and pagination
  work just fine...

  @post.tag_ids       ==> list of tag ids
  @post.tags = ...    ==> set with list of tag objects
  @post.tag_ids = ... ==> set with list of ids
  @post.add_tag(id)
  @post.remove_tag(id)

And the tags get :
  @tag.posts          ==> list of posts
  @tag.post_ids       ==> list of post ids
  @tag.posts = ...    ==> set with list of post objects
  @tag.post_ids = ... ==> set with list of ids
  @tag.add_post(id)
  @tag.remove_post(id)
  
As an extra, you get 'tags_for_form' and 'posts_for_form' : a list of all 'tags' or 'posts' with the attribute 'link_id' not null if
the two objects are linked. Example :
  @post.tags_for_form = ['art object with link_id=nil', 'news object with link_id=3'] ==> @post has a link to news. *Beware* that this finder will *only* find objects which are of the same kind or subclasses of the class of the linked object (Tag here)

Linkable is great for single table inheritance and lots of 'roles' between classes. It is also very easy to create a new role like
'hot' topic for example. Having the hottest post on each project is easy as adding a check box on the post edit page and adding
the 'hot' roles :

  class Section < ActiveRecord::Base
    link :hot, :class_name=>'Post', :unique=>true
  end

  class Post < ActiveRecord::Base
    link :hot_for, :class_name=>'Section', :as_unique=>true, :unique=>true
  end

on the post edit page :
  <input type="checkbox" id="post_hot_for_id" name="post[hot_for_id]" value="<%= @project.id %>" />

=end
    module Linkable
      class << self
        def plural_method?(method)
          m = method.split('_').first
          m.pluralize == m || method.ends_with?('_for')
        end
      end
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      
      # List the links, grouped by role
      def role_links
        res = []
        self.class.roles.each do |role|
          if role[:collector]
            limit = 5
          else
            limit = nil
          end
          links = secure(Node) { Node.find(:all,
                          :select     => "#{Node.table_name}.*, links.id AS link_id, links.role", 
                          :joins      => "INNER JOIN links ON #{Node.table_name}.id=links.#{role[:other_side]}",
                          :conditions => ["links.#{role[:link_side]} = ? AND links.role = ?", self[:id], role[:role] ],
                          :order => "link_id DESC",
                          :limit => limit )} || []
          res << [role, links] if links != []
        end
        res
      end
      
      # add a link without passing by normal set/remove (this is used in forms when 'role' is used as a parameter)
      def add_link(method, other_id)
        role = nil
        method = method.to_s
        role = self.class.role[method]
        unless role
          errors.add(method, 'not a correct method')
          return false 
        end
        sym = nil
        if role[:unique]
          sym = "#{method}_id=".to_sym
        else
          sym = "add_#{method.singularize}".to_sym
        end
        self.send(sym, other_id)
        return true
      end
      
      def link=(hash)
        add_link(hash['role'], hash['other_id'])
      end
      
      # remove a link
      def remove_link(link_id)
        link = Link.find(link_id)
        if link[:source_id] == self[:id]
          link_side = 'source_id'
          other_id  = link[:target_id]
        elsif link[:target_id] == self[:id]
          link_side = 'target_id'
          other_id  = link[:source_id]
        else
          raise ActiveRecord::RecordNotFound, "Bad link id"
        end
        role = link[:role]
        link = nil
        self.class.roles.each do |r|
          if r[:role] == role && r[:link_side] == link_side
            link = r
            break
          end
        end
        unless link
          raise ActiveRecord::RecordNotFound, "Bad link id"
        end
        if link[:unique]
          sym = "#{link[:method]}_id=".to_sym
          self.send(sym, nil)
        else
          sym = "remove_#{link[:method].singularize}".to_sym
          self.send(sym, other_id)
        end
        return true
      end
      
      # calls the method defined with link. This is a wrapper used by templating systems to avoid calling arbitrary methods
      def relation(method)
        return nil unless self.class.role[method]
        self.send(method.to_sym)
      end
      
      def fetch_link(link_name, options)
        return nil unless link_def = self.class.defined_role[link_name]
        return nil unless options[:from] || self.class.role[link_name]
        klass      = link_def[:class]
        klass      = Module.const_get(link_def[:class].to_sym) if klass.kind_of?(String)
        link_side  = link_def[:link_side]
        other_side = link_def[:other_side]
        role       = link_def[:role]
        count      = link_def[:count]
        
        conditions = options[:conditions]
        options.delete(:conditions)
        # :from
        side_cond = ""
        params    = []
        case options[:from]
        when 'site'  
          count = :all
        when 'project'
          if conditions.kind_of?(Array)
            conditions[0] = "(#{conditions[0]}) AND section_id = ?"
            conditions << self[:section_id]
          elsif conditions
            conditions = ["(#{conditions}) AND section_id = ?", self[:section_id]]
          else
            conditions = ["section_id = ?", self[:section_id]]
          end
          count = :all
        else
          side_cond = " AND links.#{link_side} = ?"
          params = [self[:id]]
        end
        options.delete(:from)
        
        if options[:or]
          join = 'LEFT'
          if options[:or].kind_of?(Array)
            or_clause = options[:or].shift
            params.unshift(options[:or])
          else
            or_clause = options[:or]
          end  
          inner_conditions = ["(#{or_clause}) OR (links.role='#{role}'#{side_cond} AND links.id IS NOT NULL)", *params ]
          options.delete(:or)
        else
          join = 'INNER'
          inner_conditions = ["links.role='#{role}'#{side_cond}", *params ]
        end
        options.merge!( :select     => "#{klass.table_name}.*, links.id AS link_id, links.role", 
                        :joins      => "#{join} JOIN links ON #{klass.table_name}.id=links.#{other_side}",
                        :conditions => inner_conditions,
                        :group      => 'id'
                        )
        if conditions
          klass.with_scope(:find=>{:conditions=>conditions}) do
            secure(klass) { klass.find(count, options ) }
          end
        else 
          secure(klass) { klass.find(count, options ) }
        end
      rescue ActiveRecord::RecordNotFound
        nil
      end
      
      module AddActsAsMethod
        @@role          = {}
        @@roles         = {}
        @@roles_for_class = {}
        @@defined_role = {}
        
        # list of links defined for this class (with superclass)
        def roles
          @@roles[self] ||= role.to_a.sort.map{|k,v| v}
        end
        
        def defined_role
          @@defined_role
        end
        
        # hash with the links defined for this class (with superclass)
        def role
          @@role[self] ||= if superclass == ActiveRecord::Base
            @@roles_for_class[self] || {}
          else
            superclass.role.merge(@@roles_for_class[self] || {})
          end
        end
        
        def roles_for_form
          roles.map {|r| [r[:method].singularize, r[:method]] }
        end
        
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
              def #{meth}_zips; res = #{method}; res ? res.map{|r| r[:zip]} : []; end
              
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
                if (obj_ids = @#{meth}_del_ids) != []
                  # remove all old links for this role
                  links = Link.find(:all, :conditions => ["links.role='#{role}' AND links.#{link_side} = ? AND links.#{other_side} IN (\#{obj_ids.join(',')})", self[:id] ])
                  links.each do |l|
                    errors.add('#{role}', 'could not be removed') unless l.destroy
                  end
                end
                
                if (obj_ids = @#{meth}_add_ids) != []
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
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Linkable