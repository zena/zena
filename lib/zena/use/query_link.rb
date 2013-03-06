require 'querybuilder'

module Zena
  module Use
    class QueryLink

      module ModelMethods
        def self.included(base)
          base.send(:include, ::QueryBuilder)
          base.extend ClassMethods
          base.query_compiler = Zena::Use::QueryLink::Compiler
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

      
      class Compiler < ::QueryBuilder::Processor
        attr_reader :node_name
        set_main_table 'links'
        set_main_class 'Link'
        set_default :order,   'comment ASC'

        # Overwrite this and take car to check for valid fields.
        def process_field(field_name)
          if %w{comment status date name}.include?(field_name)
            field_name = 'comment' if field_name == 'name'
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
      
    end # QueryLink
  end # Use
end # Zena