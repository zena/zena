# This is replaced by public_attributes

# Only zafu_context definition is needed

module Zena
  module Use
    module Zafu
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end

      module ViewMethods
        include Common
        
        # main node before ajax stuff (the one in browser url)
        def start_node
          @start_node ||= if params[:s]
            secure!(Node) { Node.find_by_zip(params[:s]) }
          else
            @node
          end
        end

        # default date used to filter events in templates
        def main_date
          # TODO: timezone for @date ?
          # .to_utc(_('datetime'), visitor.tz)
          @date ||= params[:date] ? Date.parse(params[:date]) : Date.today
        end

        # Return sprintf formated entry. Return '' for values eq to zero.
        def sprintf_unless_zero(fmt, value)
          value.to_f == 0.0 ? '' : sprintf(fmt, value)
        end
        
        # list of page numbers links
        def page_numbers(current, count, join_string = nil, max_count = nil)
          max_count ||= 10
          join_string ||= ''
          join_str = ''
          if count <= max_count
            1.upto(count) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          else
            # only first pages (centered around current page)
            if current - (max_count/2) > 0
              finish = [current + (max_count/2),count].min
            else
              finish = [max_count,count].min
            end

            start  = [finish - max_count + 1,1].max

            start.upto(finish) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          end
        end
        
        # Group an array of records by key.
        def group_array(list)
          groups = []
          h = {}
          list.each do |e|
            key = yield(e)
            unless group_id = h[key]
              h[key] = group_id = groups.size
              groups << []
            end
            groups[group_id] << e
          end
          groups
        end

        def sort_array(list)
          list.sort do |a,b|
            va = yield([a].flatten[0])
            vb = yield([b].flatten[0])
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def min_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def max_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              vb <=> va
            elsif vb
              1
            elsif va
              -1
            else
              0
            end
          end
        end
        
        # TODO: test
        # display the title with necessary id and checks for 'lang'. Options :
        # * :link if true, the title is a link to the object's page
        #   default = true if obj is not the current node '@node'
        # * :project if true , the project name is added before the object title as 'project / .....'
        #   default = obj project is different from current node project
        # if no options are provided show the current object title
        def show_title(opts={})
          obj = opts[:node] || @node

          unless opts.include?(:link)
            # we show the link if the object is not the current node or when it is being created by zafu ajax.
            opts[:link] = (obj[:id] != @node[:id] || params[:t_url]) ? 'true' : nil
          end

          unless opts.include?(:project)
            opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id]) 
          end

          title = opts[:text] || obj.version.title
          if opts[:project] && project = obj.project
            title = "#{project.name} / #{title}"
          end

          title += check_lang(obj) unless opts[:check_lang] == 'false'
          title  = "<span id='v_title#{obj.zip}'>#{title}</span>"

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
                  link_opts[:format] = obj.c_ext
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
        
        
      end # ViewMethods
      
      module ModelMethods
        def self.included(base)
          zafu_class_methods = <<-END
            @@_zafu_context   ||= {} # defined for each class (list of methods to change contexts)
            @@_zafu_known_contexts      ||= {} # full list with inherited attributes

            def self.zafu_context(hash)
              @@_zafu_context[self] ||= {}
              @@_zafu_context[self].merge!(hash.stringify_keys)
            end

            def self.zafu_known_contexts
              @@_zafu_known_contexts[self] ||= begin
                res = {}
                if superclass == ActiveRecord::Base
                  @@_zafu_context[self] || {}
                else
                  superclass.zafu_known_contexts.merge(@@_zafu_context[self] || {})
                end.each do |k,v|
                  if v.kind_of?(Hash)
                    res[k] = v.merge(:node_class => parse_class(v[:node_class]))
                  else
                    res[k] = {:node_class => parse_class(v)}
                  end
                end
                res
              end
            end

            def self.parse_class(klass)
              if klass.kind_of?(Array)
                if klass[0].kind_of?(String)
                  [Module::const_get(klass[0])]
                else
                  klass
                end
              else
                if klass.kind_of?(String)
                  Module::const_get(klass)
                else
                  klass
                end
              end
            end
          END
        
          base.send(:class_eval, zafu_class_methods)
        end
      end # ModelMethods
    end # Zafu
  end # Use
end # Zena