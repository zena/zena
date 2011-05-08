module Zena
  module Use
    module Calendar
      DAY_FORMAT = '%Y-%m-%d'

      module ViewMethods
        def cal_day_names(size, week_start_day)
          if size == :tiny
            day_names = Date::ABBR_DAYNAMES
          else
            day_names = Date::DAYNAMES
          end

          res = ""
          0.upto(6) do |i|
            j = (i+week_start_day) % 7
            if j == 0
              html_class = " class='sun'"
            elsif j == 6
              html_class = " class='sat'"
            end
            res << "<th#{html_class}>#{_(day_names[j])}</th>"
          end
          res
        end

        # find start and end dates for a calendar showing a specified date
        def cal_start_end(utc_date, type, tz, week_start_day)
          # We need to compute start/end in local tz
          date = tz.utc_to_local(utc_date)

          case type
          when :week
            # week
            start_date  = date
            end_date    = date
          else
            # month
            # From 2000-10-01 00:00
            start_date  = Time.utc(date.year, date.mon, 1)
            # To   2000-11-01 00:00
            end_date    = start_date.advance(:months => 1)
          end

          start_date = start_date.advance(:days => -((start_date.wday + 7 - week_start_day) % 7))
          # end_date.wday - 1 because at 00:00 this is considered to be the next day but we do not
          # show this day.
          end_date = end_date.advance(:days => (6 + week_start_day - (end_date.wday - 1)) % 7)
          # convert back to UTC
          [tz.local_to_utc(start_date.to_time), tz.local_to_utc(end_date)]
        end

        # Get day class. The first parameter is an UTC Date. The second is a local Time.
        def cal_class(utc_date, local_ref, tz)
          date = tz.utc_to_local(utc_date.to_time)
          @cal_today ||= tz.utc_to_local(Time.now).strftime(DAY_FORMAT)
          case date.wday
          when 6
            s = "sat"
          when 0
            s = "sun"
          else
            s = ""
          end
          s +=  'other' if date.mon != local_ref.mon
          s = s == '' ? [] : [s]
          s <<  'today' if date.strftime(DAY_FORMAT) == @today
          s <<  'ref'   if date.strftime(DAY_FORMAT) == local_ref.strftime(DAY_FORMAT)
          s == [] ? '' : " class='#{s.join(' ')}'"
        end

        # Yield block for every week between 'start_date' and 'end_date' with a hash of days => events.
        def cal_weeks(date_attr, list, start_date, end_date, tz, hours = nil)
          # build event hash
          cal_hash = {}
          if hours
            # hours should contain 0 and should be sorted
            # [0,12] ==> 0  => dates from 00:00 to 11:59
            #            12 => dates from 12:00 to 23:59

            (list || []).each do |n|
              # d is an UTC date
              utc_d = n.send(date_attr) rescue nil
              next unless utc_d && utc_d.kind_of?(Time)
              d = tz.utc_to_local(utc_d)
              hours.reverse_each do |h|
                if d.hour >= h
                  # too bad Time does not have an hour= method, we could have written d.hour = h
                  # d = d - (d.hour - h) * 3600
                  # # we need this to properly display hour class in ajax return ?
                  # n.send("#{date_attr}=", d)

                  # d = local date
                  h_list = cal_hash[d.strftime('%Y-%m-%d %H')] ||= []
                  h_list << n
                  break
                end
              end
            end

          else
            (list || []).each do |n|
              utc_d = n.send(date_attr)
              next unless utc_d
              d = tz.utc_to_local(utc_d)
              h_list = cal_hash[d.strftime('%Y-%m-%d 00')] ||= []
              h_list << n
            end
          end

          # Date#step includes the last date [first, last] but we need [first, last[
          start_date.to_datetime.step(end_date.to_datetime.advance(:seconds => -1),7) do |week|
            # each week (UTC Date)
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
            date_format = "%Y-%m-%dT%H"
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

        # Display calendar content
        def r_calendar
          # Should work like r_block (storage/rendering)
          display_calendar
          #if @context[:block] == self
          #  # called from self (storing template / rendering)
          #  if role = @params[:assign_as]
          #    assign_calendar(role)
          #  else
          #    display_calendar
          #  end
          #else
          #  # This is called first to prepare calendar
          #  if @params[:assign_as]
          #    fld = 'date'
          #    table_name = 'links'
          #  else
          #    fld = @params[:date] || 'event_at'
          #    if ['log_at', 'created_at', 'updated_at', 'event_at'].include?(fld) # TODO: use rubyless to learn type
          #      table_name = 'nodes'
          #    elsif fld == 'l_date'
          #      fld = 'date'
          #      table_name = 'links'
          #    else
          #      return parser_error("Invalid 'date' value for calendar (#{fld.inspect}).")
          #    end
          #  end
          #
          #  @date_scope = "TABLE_NAME[#{table_name}].#{fld} >= '\#{start_date.strftime('%Y-%m-%d')}' AND TABLE_NAME[#{table_name}].#{fld} <= '\#{end_date.strftime('%Y-%m-%d')}'"
          #
          #  new_dom_scope
          #
          #  # SAVED TEMPLATE
          #  template = expand_block(self, :block => self, :saved_template => true)
          #  out helper.save_erb_to_url(template, template_url)
          #
          #  # INLINE
          #  out expand_block(self, :block => self, :saved_template => false)
          #end
        end

        private
          def display_calendar
            opts = {
              :size => (@params[:size]  || 'large').to_sym
            }
            return parser_error("Missing 'select' parameter.") unless opts[:select] = @params[:select]

            if header_block = descendant('header')
            elsif @params[:type] == 'week'
              add_block(%q{<h3 do='header'>
                <r:link date='#{date.advance(:days =&gt; -1).strftime("%Y-%m-%d", tz)}' t='img_prev_page'/>
                <r:date format='%B'/>
                <r:link date='#{date.advance(:days =&gt; 1).strftime("%Y-%m-%d", tz)}' t='img_next_page'/>
              </h3>}, true)
              header_block = descendant('header')
            else
              add_block(%q{<h3 do='header'>
                <r:link date='#{date.advance(:months =&gt; -1).strftime("%Y-%m-%d", tz)}' t='img_prev_page'/>
                <r:date format='%B'/>
                <r:link date='#{date.advance(:months =&gt; 1).strftime("%Y-%m-%d", tz)}' t='img_next_page'/>
              </h3>}, true)
              header_block = descendant('header')
            end

            if cell_block = descendant('cell')
            else
              # add a default <r:link/> block
              if opts[:size] == :tiny
                add_block %Q{<r:cell><em do='link' date='#{format_date(date, "%Y-%m-%d")}' do='date' format='%e'/></r:cell>}
              else
                add_block "<r:cell><p do='date' format='%e'/><ol><li do='each' do='link' eval='title.limit(10)'/></ol></r:cell>"
              end
              cell_block = descendant('cell')
            end

            if !cell_block.descendant('else')
              cell_block.add_block %q{<r:else do='date' format='%e'/>}
            end

            opts[:cell] = cell_block
            opts[:header] = header_block
            opts[:current_date] = get_var_name('calendar', 'c_date')
            make_calendar(opts)
          end

          def make_calendar(opts)
            current_date = opts[:current_date]
            type = params[:type] ? params[:type].to_sym : :month

            size = opts[:size]

            if params[:assign_as]
              date_attr = 'l_date'
            else
              return parser_error("Missing 'attr' attribute.") unless date_attr = params[:attr]
            end

            day_var   = get_var_name('calendar', 'day')

            week_var  = get_var_name('calendar', 'week')

            if tz_name = @params[:tz]
              tz_result, tz_var = set_tz_var(tz_name)
              return tz_result unless tz_var
              set_tz = tz_result
            else
              tz_var    = get_var_name('calendar', 'tz')
              set_tz = "<% #{tz_var} = visitor.tz %>"
            end

            cell_date = get_var_name('calendar', 'date')
            cal_start = get_var_name('calendar', 'cal_start')
            cal_end   = get_var_name('calendar', 'cal_end')

            # To avoid wrapping in each cell
            markup = @markup
              @markup = Zafu::Markup.new(nil) # dummy to avoid cell wrapping

              # Declare calendar var 'cal_start' and 'cal_end' (can be used in header)
              set_context_var('set_var', 'cal_start', RubyLess::TypedString.new(
                cal_start,
                :class => Time
              ))

              set_context_var('set_var', 'cal_end', RubyLess::TypedString.new(
                cal_end,
                :class => Time
              ))

              set_context_var('set_var', 'tz', RubyLess::TypedString.new(
                tz_var,
                :class => TZInfo::Timezone
              ))


              if date_code = @params[:date]
                c_date_code = RubyLess.translate(self, date_code)
                if !c_date_code.klass <= Time
                  return parser_error("Invalid 'date' parameter. Should be a Time (found #{current_date.klass})")
                end
              else
                # Get current date from url for the current time_zone
                c_date_code = RubyLess.translate(self, 'date(tz)')
              end
              set_current_date = "#{current_date} = #{c_date_code}"

              # 'current date' for the whole calendar
              set_context_var('set_var', 'date', RubyLess::TypedString.new(
                current_date,
                :class => Time
              ))

              # BUILD FINDER
              return unless finder = build_finder(:all, opts[:select])

              klass = finder[:query].main_class
              return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)

              if type = klass.safe_method_type([date_attr])
                if type[:class] <= Time
                  # OK
                else
                  return parser_error("Invalid attribute '#{date_attr}': type is '#{type[:class]}' should be Time")
                end
              else
                return parser_error("Invalid attribute '#{date_attr}' for #{klass}")
              end
              # HACK to overwrite 'header' method...
              h = opts[:header]
              h.method = 'void'
              header_code = expand_block(h)
              h.method = 'header'

              # Date for the cell
              set_context_var('set_var', 'date', RubyLess::TypedString.new(
                cell_date,
                :class => Time
              ))


              # HACK to render sub-elements...
              bak = @blocks
                @blocks = opts[:cell].blocks
                cell_code   = expand_if(var, node.move_to(var, [klass]))
              @blocks = bak
            @markup = markup

            # Reference date (the one in the url) as seen by the calendar's timezone.
            local_ref = get_var_name('calendar', 'local_ref')
            set_local_ref = "<% #{local_ref} = #{tz_var}.utc_to_local(#{current_date}) %>"

            week_start_day = param(:start_day) || _('week_start_day').to_i

            # List of events for each day/hour (hour is 00 when not used)
            # The time is encoded in the visitor's timezone.
            # '%Y-%m-%d %H' => [...]
            events_hash  = get_var_name('calendar', 'nodes')

            base_class = node.real_class <= Node ? Node : node.real_class

            if hours = @params[:split_hours]
              hours = hours.split(',').map{|l| l.to_i}
              hours << 0
              hours = hours.uniq.sort
              # I feel all this would be much better if we could use "each_group" but then how do we access hours ?

              hour_var = get_var_name('calendar', 'hour')

              week_code = "<% #{week_var}.step(#{week_var}+6,1) do |#{day_var}| %>
              <td<%= cal_class(#{day_var},#{local_ref}, #{tz_var}) %>>#{opts[:cell_prefix_code]}<% #{hours.inspect}.each do |#{hour_var}|; #{cell_date} = #{day_var}.to_time.advance(:hours => #{hour_var}); #{var} = #{events_hash}[#{cell_date}).strftime_tz('%Y-%m-%d %H',#{tz_var})] %>#{cell_code}<% end %>#{opts[:cell_postfix_code]}</td>
              <% end %>"
              (@context[:vars] ||= []) << "hour"
            else
              hours = nil
              week_code = "<% #{week_var}.step(#{week_var}+6,1) do |#{day_var}| %>
              <td<%= cal_class(#{day_var},#{local_ref}, #{tz_var}) %>><% #{cell_date} = #{day_var}.to_time; #{var} = #{events_hash}[#{cell_date}.strftime_tz('%Y-%m-%d 00',#{tz_var})] %>#{opts[:cell_prefix_code]}#{cell_code}#{opts[:cell_postfix_code]}</td>
              <% end %>"
            end


            out "#{set_tz}<% if #{set_current_date} %>"
            out wrap %Q{#{set_local_ref}#{header_code}
              <table cellspacing='0' class='#{size}cal#{@params[:assign_as] ? " assign" : ''}'>
                <tr><%= cal_day_names(#{size.inspect}, #{week_start_day}) %></tr>
                  <% #{cal_start}, #{cal_end} = cal_start_end(#{current_date}, #{type.inspect}, #{tz_var}, #{week_start_day}) %>
                  <% cal_weeks(#{date_attr.inspect}, #{finder[:method]}, #{cal_start}, #{cal_end}, #{tz_var}, #{hours.inspect}) do |#{week_var}, #{events_hash}| %>
                  <tr class='body'>
                    #{week_code}
                  </tr>
                <% end %>
              </table>}
            out "<% end %>"
          rescue ::QueryBuilder::Error => err
            out parser_error(err.message)
          end
        # Calendar methods need a rewrite...
=begin

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

=end
      end # ZafuMethods
    end # Calendar
  end # Use
end # Zena