module Zena
  module Use
    module Urls
      module Common
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
          if sharp = options.delete(:sharp)
            if sharp =~ /\[(.+)\]/
              sharp_value = node.public_read($1)
            elsif sharp == 'true'
              sharp_value = "node#{node[:zip]}"
            else
              sharp_value = sharp
            end
            if sharp_in = options.delete(:sharp_in)
              sharp_node = sharp_in.kind_of?(Node) ? sharp_in : (node.find(:first, [sharp_in]) || node)
              return "#{zen_path(sharp_node, options)}##{sharp_value}"
            else
              return "##{sharp_value}"          
            end
          end

          opts   = options.dup
          format = opts.delete(:format)
          format = 'html' if format.blank?
          pre    = opts.delete(:prefix) || prefix
          mode   = opts.delete(:mode)
          host   = opts.delete(:host)
          abs_url_prefix = host ? "http://#{host}" : ''

          if asset = opts.delete(:asset)
            mode   = nil
          end

          params = (opts == {}) ? '' : ('?' + opts.map{ |k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&'))

          if !asset && node[:id] == current_site[:root_id] && mode.nil? && format == 'html'
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
          end + params
        end

        # Url for a node. Options are 'mode' and 'format'
        # ex 'http://test.host/en/document34_print.html'
        def zen_url(node, opts={})
          zen_path(node,opts.merge(:host => current_site[:host]))
        end

        # Return the path to a document's data
        def data_path(node, opts={})
          return zen_path(node,opts) unless node.kind_of?(Document)
          if node.public? && !current_site.authentication?
            # force the use of a cacheable path for the data, even when navigating in '/oo'
            # FIXME: we could use 'node.version.lang' if most of the time the version is loaded.
            zen_path(node, opts.merge(:format => node.c_ext, :prefix=>node.v_lang))
          else  
            zen_path(node, opts.merge(:format => node.c_ext))
          end
        end
        
        # Url parameters (without format/mode/prefix...)
        def query_params
          res = {}
          path_params.each do |k,v|
            next if [:mode, :format, :asset].include?(k.to_sym)
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