module Zena
  module Use
    module Display
      module ViewMethods

        include RubyLess
        safe_method [:sprintf, String, Number] => {:class => String, :method => 'sprintf'}
        safe_method [:search_box, {:ajax => String, :type => String}] => String

        # Return sprintf formated entry. Return '' for values eq to zero.
        def sprintf_unless_zero(fmt, value)
          value.to_f == 0.0 ? '' : sprintf(fmt, value)
        end

        # Display a search field
        def search_box(opts={})
          render_to_string(:partial=>'search/form', :locals => {:ajax => opts[:ajax], :type => opts[:type]})
        end
=begin
        def title(node, opts = {})
          if node.kind_of?(Version)
            node = node.node
          end
          title_params = {}

          title_params[:check_lang] = @params[:check_lang] if @params.include?(:check_lang)

          if @params[:link]
            value, static = parse_attributes_in_value(@params[:link], :erb => false)
            link_param = ", :link=>\"#{value}\""
          else
            link_param = ''
          end

          res = "<%= show_title(:node=>#{node}#{link_param}#{params_to_erb(title_params)}"
          if @params[:text]
            res << ", :text=>#{@params[:text].inspect}"
          elsif @params[:attr]
            res << ", :text=>#{node_attribute(@params[:attr])}"
          end

          if @params.include?(:project)
            res << ", :project=>#{@params[:project] == 'true'}"
          end
          res << ")"
          if @params[:actions]
            res << " + node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>auto_publish_param)})"
          end
          res << "%>"
          res
        end
          # TODO: test
          # display the title with necessary id and checks for 'lang'. Options :
          # * :link if true, the title is a link to the object's page
          #   default = true if obj is not the current node '@node'
          # * :project if true , the project name is added before the object title as 'project / .....'
          #   default = obj project is different from current node project
          # if no options are provided show the current object title
          def title(obj, opts={})

            unless opts.include?(:link)
              # we show the link if the object is not the current node or when it is being created by zafu ajax.
              opts[:link] = (obj[:id] != @node[:id] || params[:t_url]) ? 'true' : nil
            end

            unless opts.include?(:project)
              opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id])
            end

            title = opts[:text] || obj.title
            if opts[:project] && project = obj.project
              title = "#{project.name} / #{title}"
            end

            title += check_lang(obj) unless opts[:check_lang] == 'false'
            title  = "<span id='title#{obj.zip}'>#{title}</span>"

            if (link = opts[:link]) && opts[:link] != 'false'
              if link =~ /\A(\d+)/
                zip = $1
                obj = secure(Node) { Node.find_by_zip(zip) }
                link = link[(zip.length)..-1]
                if link[0..0] == '_'
                  link = link[1..-1]
                end
              end
              if link =~ /\Ahttp/
                "<a href='#{link}'>#{title}</a>"
              else
                link_opts = {}
                if link == 'true'
                  # nothing special for the link format
                elsif link =~ /(\w+\.|)data$/
                  link_opts[:mode] = $1[0..-2] if $1 != ''
                  if obj.kind_of?(Document)
                    link_opts[:format] = obj.ext
                  else
                    link_opts[:format] = 'html'
                  end
                elsif link =~ /(\w+)\.(\w+)/
                  link_opts[:mode]   = $1
                  link_opts[:format] = $2
                elsif !link.blank?
                  link_opts[:mode]   = link
                end
                "<a href='#{zen_path(obj, link_opts)}'>#{title}</a>"
              end
            else
              title
            end
          end
      end
=end
      end # ViewMethods

      module ZafuMethods
        include RubyLess

        safe_method [:zazen, String] => :r_zazen

        # Parse text with zazen helper
        def r_zazen(signature = nil)
          @markup.prepend_param(:class, 'zazen')
          node = node(Node)
          if signature
            {
              :class  => String,
              :method => 'zazen',
              :accept_nil => true,
              :append_hash => {:node => ::RubyLess::TypedString.new(node.to_s, :class => node.klass)}
            }
          elsif attribute = @params[:attr]
            type = node.klass.safe_method_type([attribute])
            return parser_error("Unknown attribute '#{attribute}'.") unless type
            klass = type[:class]
            "<%= zazen(#{node}.#{type[:method]}, :node => #{node}) %>"
          else
            return parser_error("Missing attribute parameter")
          end
        end

        def get_attribute_or_eval(use_string_block = true)
          if attribute = @params[:attr]
            if type = node.klass.safe_method_type([attribute])
              ["#{node}.#{type[:method]}", type[:class]]
            else
              return parser_error("Unknown attribute '#{attribute}'.")
            end
          elsif code = @params[:eval]
            res = RubyLess.translate(code, self)
            [res, res.klass]
          elsif text = @params[:text]
            res = RubyLess.translate_string(text, self)
            [res, res.klass]
          elsif use_string_block && @blocks.size == 1 && @blocks.first.kind_of?(String)
            res = RubyLess::TypedString.new(@blocks.first.inspect, :class => String, :literal => @blocks.first)
            [res, res.klass]
          else
            return parser_error("Missing attribute/eval parameter")
          end
        end

        # Display an attribute or RubyLess code
        def r_show
          method, klass = get_attribute_or_eval
          return nil unless method

          if klass.ancestors.include?(String)
            res = show_string(method)
          elsif klass.ancestors.include?(Number)
            res = show_number(method)
          elsif klass.ancestors.include?(Time)
            res = show_time(method)
          else
            res = show_string("#{method}.to_s")
          end


          if @params[:live] == 'true'
            erb_id = "_#{@params[:attr]}<%= #{node}.zip %>"
            if !@markup.tag || @markup.has_param?(:id) || @out_post != ''
              # Do not overwrite id or use span if we have post content (actions) that would disappear on live update.
              res = "<span id='#{erb_id}'>#{res}</span>"
            else
              @markup.set_dyn_params(:id => erb_id)
            end
          end

          res
        end

        # Insert javascript asset tags
        def r_javascripts
          if @params[:list].nil?
            list = %w{ prototype effects tablekit zena }
          elsif @params[:list] == 'all'
            list = %w{ prototype effects dragdrop tablekit zena }
          else
            list = @params[:list].split(',').map{|e| e.strip}
          end
          helper.javascript_include_tag(*list)
        end

        # Insert stylesheet asset tags
        def r_stylesheets
          if @params[:list] == 'all' || @params[:list].nil?
            list = %w{ zena code }
          else
            list = @params[:list].split(',').map{|e| e.strip}
          end
          list << {:media => @params[:media]} if @params[:media]
          helper.stylesheet_link_tag(*list)
        end

        # Used by zafu templates that act as layouts (adminLayout for example) to insert the content if present
        # or render.
        def r_content_for_layout
          "<% if content_for_layout = yield -%><%= content_for_layout %><% else -%>" +
          expand_with +
          "<% end -%>"
        end

        # Display the page's default title
        def r_title_for_layout
          "<% if @title_for_layout -%><%= @title_for_layout %><% elsif @node && !@node.new_record? -%><%= @node.rootpath %><% elsif @node.parent -%><%= @node.parent.rootpath %><% else -%>" +
          expand_with +
          "<% end -%>"
        end

        def show_number(method)
          if fmt = @params[:format]
            begin
              # test argument
              sprintf(fmt, 123.45)
            rescue ArgumentError
              return parser_error("incorect format #{fmt.inspect}")
            end

            if fmt =~ /%[\d\.]*f/
              modifier = ".to_f"
            elsif fmt =~ /%[\d\.]*i/
              modifier = ".to_i"
            else
              modifier = ''
            end

            if @params[:zero] == 'hide'
              "<%= sprintf_unless_zero(#{fmt.inspect}, #{method}#{modifier}) %>"
            else
              "<%= sprintf(#{fmt.inspect}, #{method}#{modifier}) %>"
            end
          else
            "<%= #{method} %>"
          end
        end

        def show_string(method)
          "<%= #{method} %>"
        end

        def show_time(method)
          if fmt = @params[:format]
            begin
              # test argument
              Time.now.strftime(fmt)
            rescue ArgumentError
              return parser_error("Incorect Time format #{fmt.inspect}")
            end

            if method.could_be_nil?
              "<%= #{method}.try(:strftime, #{fmt.inspect}) %>HOP"
            else
              "<%= #{method}.strftime(#{fmt.inspect}) %>"
            end
          else
            "<%= #{method} %>"
          end
        end
      end
    end # Display
  end # Use
end # Zena