module Zena
  module Acts
=begin
Linkable provides the 'link' macro.

This macro works with a 'links' table with 'role', 'source_id' and 'target_id' fields (plus 'id' auto increment). With this
set, you can create 'roles' between objects. For example if you have a class Person, you could add
class Person < ActiveRecord::Base
  link :wife,    :class_name=>'Person',  :unique=>true, :as_unique=>true
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
@post.tags_for_form = ['art object with link_id=nil', 'news object with link_id=3'] ==> @post has a link to news.

Linkable is great for single table inheritance and lots of 'roles' between classes. It is also very easy to create a new role like
'hot' topic for example. Having the hottest post on each project is easy as adding a check box on the post edit page and adding
the 'hot' roles :

class Project < ActiveRecord::Base
  link :hot, :class_name=>'Post', :unique=>true
end

class Post < ActiveRecord::Base
  link :hot_for, :class_name=>'Project', :as_unique=>true, :unique=>true
end

on the post edit page :
<input type="checkbox" id="post_hot_for_id" name="post[hot_for_id]" value="<%= @project.id %>" />

=end
    module Linkable
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        # define dummy 'secure' and 'secure_write' to work out of Zena
        
        def link(method, options={})
          unless instance_methods.include?('secure')
            class_eval "def secure(*args); yield; end"
            class_eval "def secure_write(*args); yield; end"
          end
          klass = options[:class_name] || method.to_s.singularize.capitalize
          if options[:for] || options[:as]
            link_side  = 'target_id'
            other_side = 'source_id'
          else
            link_side  = 'source_id'
            other_side = 'target_id'
          end
          key = options[:as] || method.to_s.downcase.singularize
          if options[:unique]
            count = ':first'
          else
            count = ':all'
          end
          finder = <<-END
            def #{method}(options={})
              conditions = options[:conditions]
              options.delete(:conditions)
              options.merge!( :select     => "\#{#{klass}.table_name}.*, links.id AS link_id", 
                              :joins      => "INNER JOIN links ON \#{#{klass}.table_name}.id=links.#{other_side}",
                              :conditions => ["links.role='#{key}' AND links.#{link_side} = ?", self[:id] ]
                              )
              if conditions
                #{klass}.with_scope(:find=>{:conditions=>conditions}) do
                  secure(#{klass}) { #{klass}.find(#{count}, options ) }
                end
              else 
                secure(#{klass}) { #{klass}.find(#{count}, options ) }
              end
            rescue ActiveRecord::RecordNotFound
              nil
            end
          END
          class_eval finder
          
          if options[:as_unique]
            destroy_if_as_unique     = <<-END
            if link2 = Link.find_by_role_and_#{other_side}('#{key}', obj_id)
              errors.add('#{key}', 'can not destroy') unless link2.destroy
            end
            END
          else
            destroy_if_as_unique = ""
          end
          
          if options[:unique]
            after_save "save_#{method}".to_sym
            methods = <<-END
              def #{method}_id=(obj_id); @#{method}_id = obj_id; end
              def #{method}=(obj); @#{method}_id = obj.id; end
              def #{method}_id
                link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                link ? link[:#{other_side}] : nil
              end
              def save_#{method}
                self.class.logger.info '=============== save_#{method} called ==============='
                return unless defined? @#{method}_id
                obj_id = @#{method}_id
                if obj_id && obj_id != ''
                  # set
                  obj_id = obj_id.to_i
                  secure_write(#{klass}) { #{klass}.find(obj_id) } # make sure we can write in the object
                  if link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                    #{destroy_if_as_unique}
                    link.#{other_side} = obj_id
                  else
                    #{destroy_if_as_unique}
                    link = Link.new(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                  end  
                  errors.add('#{key}', 'cannot set') unless link.save
                else
                  # remove
                  if link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                    errors.add('#{key}', 'cannot remove') unless link.destroy
                  end
                end
                remove_instance_variable :@#{method}_id
                return true
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
                return false
              end
            END
          else
            # multiple
            meth = method.to_s.singularize
            if link_side == 'source_id'
              breaker = ""
            else
              breaker = "secure_write(#{klass}) { #{klass}.find(obj_id) }"
            end
            methods = <<-END
              def #{meth}_ids=(obj_ids)
                @#{meth}_ids = obj_ids
              end
              def #{method}=(objs)
                @#{meth}_ids = objs.map {|obj| obj.id}
              end
              def #{meth}_ids; #{method}.map{|r| r[:id]}; end
                
              def save_#{method}
                self.class.logger.info '=============== save_#{method} called ==============='
                return unless @#{meth}_ids.kind_of?(Array)
                obj_ids = @#{meth}_ids.map{|i| i.to_i }
                # remove all old links for this role
                #{method}.each do |l|
                  obj_id = l[:id]
                  if obj_ids.include?(obj_id)
                    obj_ids.delete(obj_id)
                    next
                  end
                  #{breaker}
                  errors.add('#{key}', 'could not clear') unless Link.find(l[:link_id]).destroy
                end
                obj_ids.each do |obj_id|
                  #{breaker}
                  #{destroy_if_as_unique}
                  errors.add('#{key}', 'cannot set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                end
                remove_instance_variable :@#{meth}_ids
                return true
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
                return false
              end
              
              def remove_#{meth}(obj_id)
                @#{meth}_ids ||= #{meth}_ids
                @#{meth}_ids.delete(obj_id.to_i)
              end
              
              def add_#{meth}(obj_id)
                @#{meth}_ids ||= #{meth}_ids
                @#{meth}_ids << obj_id.to_i
              end
              
              def #{method}_for_form
                secure_write(#{klass}) { #{klass}.find( :all,
                                   :select     => "\#{#{klass}.table_name}.*, links.id AS link_id", 
                                   :joins      => "LEFT OUTER JOIN links ON \#{#{klass}.table_name}.id=links.#{other_side} AND links.role='#{key}' AND links.#{link_side} = \#{self[:id].to_i}" ) }
              rescue ActiveRecord::RecordNotFound
                []
              end
                
            END
          end
          class_eval methods
          after_save   "save_#{method}".to_sym
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Linkable