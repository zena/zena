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
            if link_side == 'source_id'
              breaker = "raise ActiveRecord::RecordNotFound unless can_drive?"
            else
              breaker = "secure_drive(#{klass}) { #{klass}.find(obj_id) }"
            end
            setter = <<-END
              def #{method}=(obj_id)
                #{breaker}
                obj_id = obj_id.to_i
                secure(#{klass}) { #{klass}.find(obj_id) } # make sure we can find the object
                if link = Link.find_by_role_and_#{link_side}('#{key}', self[:id])
                  if obj_id
                    link.#{other_side} = obj_id
                    errors.add('#{key}', 'cannot set') unless link.save
                  else
                    errors.add('#{key}', 'cannot remove') unless link.destroy
                  end
                elsif obj_id
                  errors.add('#{key}', 'cannot set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                end
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
              end
            END
          else
            # multiple
            if link_side == 'source_id'
              breaker1 = "raise ActiveRecord::RecordNotFound unless can_drive?"
              breaker2 = ""
            else
              breaker1 = ""
              breaker2 = "raise ActiveRecord::RecordNotFound unless secure_drive(#{klass}) { #{klass}.find(obj_id) }"
            end
            setter = <<-END
              def #{method}=(obj_ids)
                #{breaker1}
                obj_ids.each do |obj_id|
                  #{breaker2}
                  unless Link.find_by_role_and_#{link_side}_and_#{other_side}('#{key}', self[:id], obj_id)
                    errors.add('#{key}', 'cannot set') unless Link.create(:#{link_side}=>self[:id], :#{other_side}=>obj_id, :role=>"#{key}")
                  end
                end
              rescue ActiveRecord::RecordNotFound
                errors.add('#{key}', 'cannot set')
              end
              
              def remove_#{key}(obj_id)
                
              end
            END
          end
          class_eval setter
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Linkable