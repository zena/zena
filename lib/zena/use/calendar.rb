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
          title = node.linked_node ? node.linked_node.v_title : _('free')
          hour  = date.strftime('%H')
          full_dom_id = "#{node.zip}_#{target_zip}_#{date.to_i}"
          res = "<li id='#{full_dom_id}' class='hour_#{hour} #{state}'>"

          if state == 'used' && remove_used.nil?
            res << title
          else
            opts = {:url => "/nodes/#{node.zip}?node[link][#{role}][date]=#{date.strftime("%Y-%m-%d+%H")}&node[link][#{role}][other_id]=#{state == 'free' ? target_zip : ''}&s=#{target_zip}&dom_id=#{full_dom_id}&t_url=#{CGI.escape(template_url)}&date=#{date.strftime("%Y-%m-%d+%H")}", :method => :put}
            if state == 'used' && remove_used == 'warn'
              opts[:confirm] = _("Delete relation '%{role}' between '%{source}' and '%{target}' ?") % {:role => role, :source => node.v_title, :target => node.linked_node.v_title}
            end
            res << link_to_remote(title, opts)
          end
          res << "</li>"
          res
        end
      end # ViewMethods
      
    end # Calendar
  end # Use
end # Zena