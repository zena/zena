module Zena
  module Use
    module Ajax
      module Common
      end # Common

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common

        def dom_id(node)
          if node.new_record?
            "#{params[:dom_id]}_form"
          elsif params[:action] == 'create' && !params[:udom_id]
            "#{params[:dom_id]}_#{node.zip}"
          else
            @dom_id || params[:udom_id] || params[:dom_id]
          end
        end


        # RJS to update a page after create/update/destroy
        def update_page_content(page, obj)
          if params[:t_id] && @node.errors.empty?
            @node = secure(Node) { Node.find_by_zip(params[:t_id])}
          end

          base_class = obj.kind_of?(Node) ? Node : obj.class

          if obj.new_record?
            # A. could not create object: show form with errors
            page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
          elsif @errors || !obj.errors.empty?
            # B. could not update/delete: show errors
            case params[:action]
            when 'destroy', 'drop'
              page.insert_html :top, params[:dom_id], :inline => render_errors
            else
              page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
            end
          elsif params[:udom_id]
            if params[:udom_id] == '_page'
              # reload page
              page << "document.location.href = document.location.href;"
            else
              # C. update another part of the page
              if node_id = params[:u_id]
                if node_id.to_i != obj.zip
                  if base_class == Node
                    instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_zip(node_id) })
                  else
                    instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_id(node_id) })
                  end
                end
              end
              page.replace params[:udom_id], :file => template_path_from_template_url(params[:u_url]) + ".erb"
              if params[:upd_both]
                @dom_id = params[:dom_id]
                page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
              end
              if params[:done] && params[:action] == 'create'
                page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
                page << params[:done]
              elsif params[:done]
                page << params[:done]
              end
            end
          else
            # D. normal update
            #if params[:dom_id] == '_page'
            #  # reload page
            #  page << "document.location.href = document.location.href;"
            #
            case params[:action]
            when 'edit'
              page.replace params[:dom_id], :file => template_path_from_template_url + "_form.erb"
      #        page << "$('#{params[:dom_id]}_form_t').focusFirstElement();"
            when 'create'
              pos = params[:position]  || :before
              ref = params[:reference] || "#{params[:dom_id]}_add"
              page.insert_html pos.to_sym, ref, :file => template_path_from_template_url + ".erb"
              if obj.kind_of?(Node)
                @node = @node.parent.new_child(:class => @node.class)
              else
                instance_variable_set("@#{base_class.to_s.underscore}", obj.clone)
              end
              page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
              if params[:done]
                page << params[:done]
              else
                page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
              end
            when 'update'
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
              page << params[:done] if params[:done]
            when 'destroy'
              page.visual_effect :highlight, params[:dom_id], :duration => 0.3
              page.visual_effect :fade, params[:dom_id], :duration => 0.3
            when 'drop'
              case params[:done]
              when 'remove'
                page.visual_effect :highlight, params[:drop], :duration => 0.3
                page.visual_effect :fade, params[:drop], :duration => 0.3
              end
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
            else
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
            end
          end
        end

      end # ViewMethods

    end # Ajax
  end # Use
end # Zena