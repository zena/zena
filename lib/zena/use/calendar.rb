module Zena
  module Use
    module Calendar

      module ViewMethods
        def cal_day_names(size)
          if size == :tiny
            day_names = Date::ABBR_DAYNAMES
          else
            day_names = Date::DAYNAMES
          end
          week_start_day = _('week_start_day').to_i
          res = ""
          0.upto(6) do |i|
            j = (i+week_start_day) % 7
            if j == 0
              html_class = " class='sun'"
            elsif j == 6
              html_class = " class='sat'"
            end
            res << "<td#{html_class}>#{_(day_names[j])}</td>"
          end
          res
        end

        # find start and end dates for a calendar showing a specified date
        def cal_start_end(date, type=:month)
          week_start_day = _('week_start_day').to_i

          case type
          when :week
            # week
            start_date  = date
            end_date    = date
          else
            # month
            start_date  = Date.civil(date.year, date.mon, 1)
            end_date    = Date.civil(date.year, date.mon, -1)
          end
          start_date -= (start_date.wday + 7 - week_start_day) % 7
          end_date   += (6 + week_start_day - end_date.wday) % 7
          [start_date, end_date]
        end

        def cal_class(date, ref)
          @today ||= Date.today
          case date.wday
          when 6
            s = "sat"
          when 0
            s = "sun"
          else
            s = ""
          end
          s +=  'other' if date.mon != ref.mon
          s = s == '' ? [] : [s]
          s <<  'today' if date == @today
          s <<  'ref' if date == ref
          s == [] ? '' : " class='#{s.join(' ')}'"
        end

        # Yield block for every week between 'start_date' and 'end_date' with a hash of days => events.
        def cal_weeks(date_attr, list, start_date, end_date, hours = nil)
          # build event hash
          cal_hash = {}
          if hours
            # hours should contain 0 and should be sorted
            # [0,12] ==> 0  => dates from 00:00 to 11:59
            #            12 => dates from 12:00 to 23:59

            (list || []).each do |n|
              d = n.send(date_attr)
              next unless d
              hours.reverse_each do |h|
                if d.hour >= h
                  d = d - (d.hour - h) * 3600 # too bad Time does not have an hour= method, we could have written d.hour = h
                  n.send("#{date_attr}=", d) # we need this to properly display hour class in ajax return
                  h_list = cal_hash[d.strftime("%Y-%m-%d %H")] ||= []
                  h_list << n
                  break
                end
              end
            end

          else
            (list || []).each do |n|
              d = n.send(date_attr)
              next unless d
              cal_hash[d.strftime("%Y-%m-%d 00")] ||= []
              cal_hash[d.strftime("%Y-%m-%d 00")] << n
            end
          end

          start_date.step(end_date,7) do |week|
            # each week
            yield(week, cal_hash)
          end
        end

        # display a calendar cell to assign 'node_a' to 'node_b' with
        # A (target_zip)
        # ... B (source_zip) ---> reference_to A, B, C, D
        #     <r:calendar assign='reference' to='main' />
        def cal_assign_cell(node, role, remove_used, target_zip=nil, date=nil, template_url=nil)
          date         ||= Time.parse(params[:date])
          target_zip   ||= params[:s]
          template_url ||= params[:t_url]
          state = node.linked_node ? (node.linked_node.zip ==  target_zip.to_i ? 'on' : 'used') : 'free'
          title = node.linked_node ? node.linked_node.title : _('free')
          hour  = date.strftime('%H')
          full_dom_id = "#{node.zip}_#{target_zip}_#{date.to_i}"
          res = "<li id='#{full_dom_id}' class='hour_#{hour} #{state}'>"

          if state == 'used' && remove_used.nil?
            res << title
          else
            date_format = "%Y-%m-%d+%H"
            opts = {:url => "/nodes/#{node.zip}?node[rel][#{role}][date]=#{date.strftime(date_format)}&node[rel][#{role}][other_id]=#{state == 'free' ? target_zip : ''}&s=#{target_zip}&dom_id=#{full_dom_id}&t_url=#{CGI.escape(template_url)}&date=#{date.strftime(date_format)}", :method => :put}
            if state == 'used' && remove_used == 'warn'
              opts[:confirm] = _("Delete relation '%{role}' between '%{source}' and '%{target}' ?") % {:role => role, :source => node.title, :target => node.linked_node.title}
            end
            res << link_to_remote(title, opts)
          end
          res << "</li>"
          res
        end
      end # ViewMethods

      module ZafuMethods
        # Calendar methods need a rewrite...
=begin
        def r_calendar
          if @context[:block] == self
            # called from self (storing template / rendering)
            if role = @params[:assign_as]
              assign_calendar(role)
            else
              display_calendar
            end
          else
            # This is called first to prepare calendar
            if @params[:assign_as]
              fld = 'date'
              table_name = 'links'
            else
              fld = @params[:date] || 'event_at'
              if ['log_at', 'created_at', 'updated_at', 'event_at'].include?(fld) # TODO: use rubyless to learn type
                table_name = 'nodes'
              elsif fld == 'l_date'
                fld = 'date'
                table_name = 'links'
              else
                return parser_error("Invalid 'date' value for calendar (#{fld.inspect}).")
              end
            end

            @date_scope = "TABLE_NAME[#{table_name}].#{fld} >= '\#{start_date.strftime('%Y-%m-%d')}' AND TABLE_NAME[#{table_name}].#{fld} <= '\#{end_date.strftime('%Y-%m-%d')}'"

            new_dom_scope

            # SAVED TEMPLATE
            template = expand_block(self, :block => self, :saved_template => true)
            out helper.save_erb_to_url(template, template_url)

            # INLINE
            out expand_block(self, :block => self, :saved_template => false)
          end
        end

        private
          def display_calendar
            size     = (params[:size]  || 'large').to_sym
            finder   = params[:select] || 'notes in project'

            if @blocks == []
              # add a default <r:link/> block
              if size == :tiny
                @blocks = [make(:void, :method=>'void', :text=>"<em do='link' date='current_date' do='[current_date]' format='%d'/><r:else do='[current_date]' format='%d'/>")]
              else
                @blocks = [make(:void, :method=>'void', :text=>"<span do='show' date='current_date' format='%d'/><ul><li do='each' do='link' attr='name'/></ul><r:else do='[current_date]' format='%d'/>")]
              end
              remove_instance_variable(:@all_descendants)
            elsif !descendant('else')
              @blocks += [make(:void, :method=>'void', :text=>"<r:else do='[current_date]' format='%d'/>")]
              remove_instance_variable(:@all_descendants)
            end

            @html_tag_done = false
            @html_tag_params[:id] = erb_dom_id
            @html_tag_params[:class] ||= "#{size}cal"
            @html_tag ||= 'div'

            finder, klass = build_finder_for(:all, finder, @params, [@date_scope])
            return unless finder
            return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)

            cell_code = "<% if #{list_var} = nodes_#{list_var}[cal_#{list_var}.strftime('%Y-%m-%d %H')] %>#{expand_with(:in_if => true, :list => list_var, :date => "cal_#{list_var}", :saved_template => nil, :dom_prefix => nil, :in_calendar => true)}<% end %>"

            render_html_tag(calendar_code(finder, "", cell_code, "", params))
          end

          # manage links from @node ---- reference ----> ...
          # <div do='calendar' assign='reference' to='main' split_hours='12' />
          def assign_calendar(as_role)
            size = (params[:size]  || 'large').to_sym
            @html_tag_done = false
            @html_tag_params[:id] = erb_dom_id
            @html_tag_params[:class] ||= "#{size}cal"
            @html_tag ||= 'div'
            if rel = RelationProxy.find_by_role(as_role.singularize)
              role = rel.this_role
            else
              return parser_error("Invalid role #{as_role.inspect}.")
            end
            finder, klass = build_finder_for(:all, role, @params, [@date_scope])
            return unless finder
            return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)

            # SAVED TEMPLATE ========
            template_url  = self.template_url + 'cell'
            template      = "<%= cal_assign_cell(@node, #{role.inspect}, #{@params[:used].inspect}) %>"
            out helper.save_erb_to_url(template, template_url)

            # we call update on node 'B'
            # A (main)
            # ... B (other node)
            #     calendar (in B context) ---- role --->

            cell_prefix_code = "<span><%= day_#{list_var}.strftime('%d').to_i %></span><ul>"
            cell_code = "<%= #{list_var} = nodes_#{list_var}[cal_#{list_var}.strftime('%Y-%m-%d %H')]; #{node}.linked_node = #{list_var} ? #{list_var}.first : nil; cal_assign_cell(#{node}, #{role.inspect}, #{@params[:used].inspect}, params[:s] || @node.zip, cal_#{list_var}, #{template_url.inspect}) %>"
            cell_postfix_code = "</ul>"
            render_html_tag(calendar_code(finder, cell_prefix_code, cell_code, cell_postfix_code, params))
          end

          def calendar_code(finder, cell_prefix_code, cell_code, cell_postfix_code, params)
            type = params[:type] ? params[:type].to_sym : :month
            size = (params[:size] || 'large').to_sym
            ref_date = params[:assign_as] ? 'l_date' : (params[:date] || 'event_at')

            case type
            when :month
              title = "\"\#{_(Date::MONTHNAMES[main_date.mon])} \#{main_date.year}\""
              prev_date = "\#{main_date.advance(:months => -1).strftime(\"%Y-%m-%d\")}"
              next_date = "\#{main_date.advance(:months =>  1).strftime(\"%Y-%m-%d\")}"
            when :week
              title = "\"\#{_(Date::MONTHNAMES[main_date.mon])} \#{main_date.year}\""
              prev_date = "\#{main_date.advance(:days => -7).strftime(\"%Y-%m-%d\")}"
              next_date = "\#{main_date.advance(:days => +7).strftime(\"%Y-%m-%d\")}"
            else
              return parser_error("invalid type (should be 'month' or 'week')")
            end

            if hours = @params[:split_hours]
              hours = hours.split(',').map{|l| l.to_i}
              hours << 0
              hours = hours.uniq.sort
              # I feel all this would be much better if we could use "each_group" but then how do we access hours ?
              week_code = "<% week.step(week+6,1) do |day_#{list_var}| %>
              <td<%= cal_class(day_#{list_var},#{current_date}) %>>#{cell_prefix_code}<% #{hours.inspect}.each do |set_hour|; cal_#{list_var} = Time.utc(day_#{list_var}.year,day_#{list_var}.month,day_#{list_var}.day,set_hour) %>#{cell_code}<% end %>#{cell_postfix_code}</td>
              <% end %>"
              (@context[:vars] ||= []) << "hour"
            else
              hours = nil
              week_code = "<% week.step(week+6,1) do |day_#{list_var}| %>
              <td<%= cal_class(day_#{list_var},#{current_date}) %>><% cal_#{list_var} = Time.utc(day_#{list_var}.year,day_#{list_var}.month,day_#{list_var}.day) %>#{cell_prefix_code}#{cell_code}#{cell_postfix_code}</td>
              <% end %>"
            end

            res = %Q{
              <h3 class='title'>
              <span><%= link_to_remote(#{_('img_prev_page').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}&date=#{prev_date}&#{start_node_s_param(:string)}\", :method => :get) %></span>
              <span class='date'><%= link_to_remote(#{title}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}&#{start_node_s_param(:string)}\", :method => :get) %></span>
              <span><%= link_to_remote(#{_('img_next_page').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}&date=#{next_date}&#{start_node_s_param(:string)}\", :method => :get) %></span>
              </h3>
              <table cellspacing='0' class='#{size}cal#{@params[:assign_as] ? " assign" : ''}'>
                <tr class='head'><%= cal_day_names(#{size.inspect}) %></tr>
                  <% start_date, end_date = cal_start_end(#{current_date}, #{type.inspect}) %>
                  <% cal_weeks(#{ref_date.to_sym.inspect}, #{finder}, start_date, end_date, #{hours.inspect}) do |week, nodes_#{list_var}| %>
                  <tr class='body'>
                    #{week_code}
                  </tr>
                <% end %>
              </table>}
          end
=end
      end # ZafuMethods
    end # Calendar
  end # Use
end # Zena