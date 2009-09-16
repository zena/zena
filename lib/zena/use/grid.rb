require 'json'

module Zena
  module Use
    module Grid
      module Common

        # Build a tabular content from a node's attribute
        def get_table_from_json(node, attribute)
          text = Node.zafu_attribute(node, attribute)
          if text.blank?
            table = [{"type"=>"table"},[["title"],["value"]]]
          else
            table = JSON.parse(text)
          end
          raise JSON::ParserError unless table.kind_of?(Array) && table.size == 2 && table[0].kind_of?(Hash) && table[0]['type'] == 'table' && table[1].kind_of?(Array)
          table
        end

      end # Common

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common
      end

    end # Grid
  end # Use
end # Zena