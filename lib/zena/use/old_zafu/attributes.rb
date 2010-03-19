module Zafu
  # All this should be replaced by RubyLess
  module Attributes
    include RubyLess::SafeClass

    PSEUDO_ATTRIBUTES = {
      'now'      => 'Time.now',
      'start.id' => '(params[:s] || @node[:zip])',
      'nil'      => 'nil',
    }


    def node_attribute(str, opts={})

      if @context[:vars] && @context[:vars].include?(str)
        return "set_#{str}"
      end

      res = PSEUDO_ATTRIBUTES[str]
      return res if res
      return current_date  if str == 'current_date'
      return get_param($1) if str =~ /^param:(\w+)$/

      attribute, att_node, klass = get_attribute_and_node(str)

      return 'nil' unless attribute


      att_node  ||= opts[:node]       || node
      klass     ||= opts[:node_class] || node_class

      real_attribute = attribute =~ /\Ad_/ ? attribute : attribute.gsub(/\A(|[\w_]+)id(s?)\Z/, '\1zip\2')

      if klass.ancestors.include?(Node)
        if ['url','path'].include?(real_attribute)
          # pseudo attribute 'url'
          params = {}
          params[:mode]   = @params[:mode]   if @params[:mode]
          params[:format] = @params[:format] if @params[:format]
          res = "zen_#{real_attribute}(#{node}#{params_to_erb(params)})"
        elsif type = safe_method_type([real_attribute])
          res = type[:method]
        elsif type = klass.safe_method_type([real_attribute])
          res = "#{att_node}.#{type[:method]}"
        else
          res = "#{att_node}.safe_read(#{real_attribute.inspect})"
        end
      elsif type = RubyLess::SafeClass.safe_method_type_for(klass, [real_attribute])
        res = "#{att_node}.#{type[:method]}"
      elsif klass.instance_methods.include?('safe_read')
        # Unknown method but safe class: can resolve at runtime
        res = "#{att_node}.safe_read(#{real_attribute.inspect})"
      else
        out parser_error("#{klass} does not respond to #{real_attribute.inspect}")
        return 'nil'
      end

      res = "(#{res} || #{node_attribute(opts[:else])})" if opts[:else]
      res = "(#{res} || #{opts[:default].inspect})" if opts[:default]
      res
    end

    def parse_attributes_in_value(v, opts = {})
      opts = {:erb => true}.merge(opts)
      static = true

      use_node  = @var || node
      res = v.gsub(/\[([^\]]+)\]/) do
        static = false
        res    = nil
        attribute = $1

        if opts[:skip_node_attributes]
          if attribute =~ /^param:(\w+)$/
            attribute = get_param($1)
          elsif attribute == 'current_date'
            attribute = current_date
          else
            res = "[#{attribute}]"
          end
        else
          attribute = node_attribute(attribute, :node => use_node )
        end

        res ||= if opts[:erb]
          "<%= #{attribute} %>"
        else
          "\#{#{attribute}}"
        end
        res
      end
      [res, static]
    end

    def get_attribute_and_node(str)
      if str =~ /([^\.]+)\.(.+)/
        node_name = $1
        node_attr = $2
        if att_node = find_stored(Node, node_name)
          return [node_attr, att_node, Node]
        elsif node_name == 'main'
          return [node_attr, '@node', Node]
        elsif node_name == 'visitor'
          return [node_attr, 'visitor.contact', Contact]
        elsif node_name == 'site'
          return [node_attr, 'current_site', Site]
        else
          out parser_error("invalid node name #{node_name.inspect} in attribute #{str.inspect}")
          return [nil]
        end
      else
        return [str]
      end
    end

  end # Attributes
end # Zafu