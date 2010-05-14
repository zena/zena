require 'querybuilder'

module Zena
  module Use
    class QueryComment

      module ModelMethods
        def self.included(base)
          base.send(:include, QueryBuilder)
          base.extend ClassMethods
          base.query_compiler = Zena::Use::QueryComment::Compiler
        end
      end

      module ClassMethods
        # Find a node and propagate visitor
        def do_find(count, query)
          case count
          when :all
            res = find_by_sql(query)
            res.empty? ? nil : res
          when :first
            find_by_sql(query).first
          when :count
            count_by_sql(query)
          else
            nil
          end
        end
      end

      class Compiler < QueryBuilder::Processor
        attr_reader :node_name
        set_main_table 'comments'
        set_main_class 'Comment'
        set_default :order,   'created_at ASC'

        # Same as QueryNode... DRY needed.
        def map_literal(value)
          if value =~ /(.*?)\[(node|visitor|param):(\w+)\](.*)/
            val_start = $1 == '' ? '' : "#{$1.inspect} +"
            val_end   = $4 == '' ? '' : "+ #{$4.inspect}"
            case $2
            when 'visitor'
              if $3 == 'user_id'
                value = "visitor.id"
              else
                value = "Node.zafu_attribute(visitor.contact, #{$3.inspect})"
              end
            when 'node'
              if $3 == 'user_id'
                value = "#{@node_name}.user_id"
              else
                value = "Node.zafu_attribute(#{@node_name}, #{$3.inspect})"
              end
            when 'param'
              return "\#{Node.connection.quote(#{val_start}params[:#{$3}].to_s#{val_end})}"
            end

            if !val_start.blank? || !val_end.blank?
              "\#{Node.connection.quote(#{val_start}#{value}#{val_end})}"
            else
              "\#{#{value}}"
            end
          else
            value = Node.connection.quote(value)
          end
        end

        # Overwrite this and take car to check for valid fields.
        def process_field(field_name)
          if %w{status updated_at author_name created_at title text author_id}.include?(field_name)
            "#{table}.#{field_name}"
          else
            super # raise an error
          end
        end

        def map_attr(fld)
          # error
          nil
        end
      end # Compiler
    end # QueryComment
  end # Use
end # Zena
