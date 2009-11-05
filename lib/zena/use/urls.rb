module Zena
  module Use
    module Urls
      module Common
        CACHESTAMP_FORMATS = ['jpg', 'png', 'gif', 'css', 'js']
        def prefix
          if visitor.is_anon?
            visitor.lang
          else
            AUTHENTICATED_PREFIX
          end
        end

        # Path for the node (as string). Options can be :format, :host and :mode.
        # ex '/en/document34_print.html'
        def zen_path(node, options={})

          return '#' unless node

          if anchor = options.delete(:anchor)
            if anchor =~ /\[(.+)\]/
              anchor_value = node.safe_read($1)
            elsif anchor == 'true'
              anchor_value = "node#{node[:zip]}"
            else
              fixed = true
              anchor_value = anchor
            end
            if anchor_in = options.delete(:anchor_in)
              anchor_node = anchor_in.kind_of?(Node) ? anchor_in : (node.find(:first, [anchor_in]) || node)
              return "#{zen_path(anchor_node, options)}##{anchor_value}"
            elsif fixed
              return "#{zen_path(node, options)}##{anchor_value}"
            else
              return "##{anchor_value}"
            end
          end

          opts   = options.dup
          format = opts.delete(:format)
          format = 'html' if format.blank?
          pre    = opts.delete(:prefix) || prefix
          mode   = opts.delete(:mode)
          host   = opts.delete(:host)
          abs_url_prefix = host ? "http://#{host}" : ''

          if node.kind_of?(Document) && format == node.version.content.ext
            if node.public? && !current_site.authentication?
              # force the use of a cacheable path for the data, even when navigating in '/oo'
              pre = node.version.lang
            end
          end

          if asset = opts.delete(:asset)
            mode   = nil
          end


          if cachestamp_format?(format) && ((node.kind_of?(Document) && node.version.content.ext == format) || asset)
            opts[:cachestamp] = make_cachestamp(node, mode)
          else
            opts.delete(:cachestamp) # cachestamp
          end

          path = if !asset && node[:id] == current_site[:root_id] && mode.nil? && format == 'html'
            "#{abs_url_prefix}/#{pre}" # index page
          elsif node[:custom_base]
            "#{abs_url_prefix}/#{pre}/" +
            node.basepath +
            (mode  ? "_#{mode}"  : '') +
            (asset ? ".#{asset}" : '') +
            (format == 'html' ? '' : ".#{format}")
          else
            "#{abs_url_prefix}/#{pre}/" +
            (node.basepath != '' ? "#{node.basepath}/"    : '') +
            (node.klass.downcase   ) +
            (node[:zip].to_s       ) +
            (mode  ? "_#{mode}"  : '') +
            (asset ? ".#{asset}" : '') +
            ".#{format}"
          end

          append_query_params(path, opts)
        end

        def append_query_params(path, opts)
          if opts == {}
            path
          else
            cachestamp = opts.delete(:cachestamp)
            list = opts.keys.map do |k|
              if value = opts[k]
                if value.respond_to?(:strftime)
                  "#{k}=#{value.strftime('%Y-%m-%d')}"
                else
                  "#{k}=#{CGI.escape(opts[k].to_s)}"
                end
              else
                nil
              end
            end.compact

            if cachestamp
              path + "?#{cachestamp}" + (list.empty? ? '' : "&#{list.sort.join('&')}")
            else
              path + (list.empty? ? '' : "?#{list.sort.join('&')}")
            end
          end
        end

        # Url for a node. Options are 'mode' and 'format'
        # ex 'http://test.host/en/document34_print.html'
        def zen_url(node, opts={})
          zen_path(node,opts.merge(:host => current_site[:host]))
        end

        # Return the path to a document's data
        def data_path(node, opts={})
          if node.kind_of?(Document)
            zen_path(node, opts.merge(:format => node.version.content.ext))
          else
            zen_path(node, opts)
          end
        end

        def cachestamp_format?(format)
          CACHESTAMP_FORMATS.include?(format)
        end

        def make_cachestamp(node, mode)
          if mode
            if node.kind_of?(Image)
              if iformat = Iformat[mode]
                "#{node.updated_at.to_i + iformat[:hash_id]}"
              else
                # random (will raise a 404 error anyway)
                "#{node.updated_at.to_i + Time.now.to_i}"
              end
            else
              # same format but different mode ? foobar_iphone.css ?
              # will not be used.
              node.updated_at.to_i.to_s
            end
          else
            node.updated_at.to_i.to_s
          end
        end

        # Url parameters (without format/mode/prefix...)
        def query_params
          res = {}
          path_params.each do |k,v|
            next if [:mode, :format, :asset, :cachestamp].include?(k.to_sym)
            res[k.to_sym] = v
          end
          res
        end

        # Url parameters (without action,controller,path,prefix)
        def path_params
          res = {}
          params.each do |k,v|
            next if [:action, :controller, :path, :prefix, :id].include?(k.to_sym)
            res[k.to_sym] = v
          end
          res
        end


      end # Common

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common
      end

    end # Urls
  end # Use
end # Zena