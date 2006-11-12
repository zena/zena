module Zena
  module Acts 
    module Linkable
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def link(method, options)
          klass = options[:class]
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
            def #{method}
              secure(#{klass}) { #{klass}.find(#{count},
                                 :select     => "items.*", 
                                 :joins      => "LEFT JOIN links ON items.id=links.#{other_side}",
                                 :conditions => ["links.role='#{key}' AND links.#{link_side} = ?", self[:id]]   ) }
            rescue ActiveRecord::RecordNotFound
              nil
            end
          END
          class_eval finder
          
          if options[:unique]
            after_save "save_#{method}".to_sym
            methods = <<-END
              def #{method}_id=(obj_id); @#{method}_id = obj_id; end
              def #{method}_id
                link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                link ? link[:#{other_side}] : nil
              end
              def save_#{method}
                return unless defined? @#{method}_id
                obj_id = @#{method}_id
                if obj_id && obj_id != ''
                  # set
                  obj_id = obj_id.to_i
                  secure(#{klass}) { #{klass}.find(obj_id) } # make sure we can find the object
                  if link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                    link.#{other_side} = obj_id
                    errors.add('#{key}', 'cannot set') unless link.save
                  else
                    errors.add('#{key}', 'cannot set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                  end
                else
                  # remove
                  if link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                    errors.add('#{key}', 'cannot remove') unless link.destroy
                  end
                end
                remove_instance_variable :@#{method}_id
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
              end
            END
          else
            # multiple
            meth = method.to_s.singularize
            attr_accessor "#{meth}_ids"
            after_save "save_#{method}".to_sym
            if link_side == 'source_id'
              breaker = ""
            else
              breaker = "raise ActiveRecord::RecordNotFound unless secure_drive(#{klass}) { #{klass}.find(obj_id) }"
            end
            methods = <<-END
              def #{meth}_ids=(obj_ids); @#{meth}_ids = obj_ids; end
              def #{meth}_ids; Link.find_all_by_role_and_#{link_side}('#{key}', self[:id]).map{|r| r[:#{other_side}]}; end
                
              def save_#{method}
                return unless @#{meth}_ids.kind_of?(Array)
                obj_ids = @#{meth}_ids.map{|i| i.to_i }
                # remove all old links for this role
                Link.find_all_by_role_and_#{link_side}('#{key}', self[:id]).each do |l|
                  obj_id = l[:#{other_side}]
                  if obj_ids.include?(obj_id)
                    obj_ids.delete(obj_id)
                    next
                  end
                  #{breaker}
                  errors.add('#{key}', 'could not clear') unless l.destroy
                end
                obj_ids.each do |obj_id|
                  #{breaker}
                  unless Link.find_by_role_and_#{link_side}_and_#{other_side}('#{key}', self[:id], obj_id)
                    errors.add('#{key}', 'cannot set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                  end
                end
                remove_instance_variable :@#{meth}_ids
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
              end
              
              def remove_#{meth}(obj_id)
                @#{meth}_ids ||= #{meth}_ids
                @#{meth}_ids.delete(obj_id.to_i)
              end
              
              def add_#{meth}(obj_id)
                @#{meth}_ids ||= #{meth}_ids
                @#{meth}_ids << obj_id.to_i
              end
            END
          end
          class_eval methods
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Linkable