# encoding: utf-8
require 'json'

module Bricks
  module Grid
    module Common

      def get_table_from_json(text)
        error = nil
        if !text.blank?
          begin
            table = JSON.parse(text) rescue nil
          end
          if table &&
             table.kind_of?(Array) &&
             table.size == 2 &&
             table[0].kind_of?(Hash) &&
             table[0]['type'] == 'table'
            # ok
          else
            table = nil
            error = "<span class='unknownLink'>could not build table from text</span>"
          end
        end

        table ||= [{"type"=>"table"},[]]

        return table, error
      end

    end # Common

    module ControllerMethods
      include Common
    end

    # Routes = {
    #  :cell_update => :post, :table_update => :post, :cell_edit => :get
    # }

    module ViewMethods
      include Common

      # Create a table from an attribute
      def make_table(opts)
        style, node, attribute = opts[:style], opts[:node], opts[:attribute]
        case (style || '').sub('.', '')
        when ">"
          prefix = "<div class='img_right'>"
          suffix = "</div>"
        when "<"
          prefix = "<div class='img_left'>"
          suffix = "</div>"
        when "="
          prefix = "<div class='img_center'>"
          suffix = "</div>"
        else
          prefix = ''
          suffix = ''
        end

        table, error = get_table_from_json(node.prop[attribute])

        res = prefix + error.to_s
        if node.can_write?
          res << "<table data-a='node[#{attribute}]' class='grid'>\n<tr>"
        else
          res << "<table><tr>"
        end


        if table[1][0]
          table[1][0].each do |heading|
            res << "<th>#{ heading }</th>"
          end
          res << "</tr>\n"
          table[1][1..-1].each do |row|
            res << "<tr>\n"
            row.each do |td|
              res << "<td>#{td}</td>\n"
            end
            res << "</tr>\n"
          end
        end
        res << "</table>\n"
        res << suffix
        res
      rescue JSON::ParserError
        "<span class='unknownLink'>could not build table from text</span>"
      end
    end

    # New better grid using JS.
    module ZafuMethods
      def r_grid
        attr = @params[:attr]
        raise parser_error("Missing 'attr' parameter") unless attr
        # Make sure it compiles
        code = RubyLess.translate(node(Node).klass, attr)
        out "<%= make_table(:attribute => #{attr.inspect}, :node => #{node(Node)}) %>"
      end
    end
  end # Grid
end # Zena

