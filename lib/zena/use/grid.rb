# encoding: utf-8
require 'json'

module Zena
  module Use
    module Grid
      module Common

        # Build a tabular content from a node's attribute
        def get_table_from_json(text)
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

        # Get cell text
        def cell_edit
          # get table
          table = get_table_from_json(@node.prop[params[:attr]])
          # get row/cell
          table_data = table[1]

          if row = table_data[params[:row].to_i]
            if cell = row[params[:cell].to_i]
              render :text => cell
            else
              ' '
            end
          else
            ' '
          end
        end

        # Ajax table editor
        def cell_update
          # FIXME: SECURITY: how to make sure we only access authorized keys for tables ?
          # get table
          table = get_table_from_json(@node.prop[params[:attr]])

          # get row/cell
          table_data = table[1]

          if row = table_data[params[:row].to_i]
            if cell = row[params[:cell].to_i]
              if cell != params[:value]
                row[params[:cell].to_i] = params[:value]
                @node.update_attributes(params[:attr] => table.to_json)
              end
            else
              @node.errors.add(params[:attr], 'Cell outside of table range.')
            end
          else
            @node.errors.add(params[:attr], 'Row outside of table range.')
          end

          respond_to do |format|
            format.html { render :inline => @node.errors.empty? ? "<%= zazen(params[:value], :no_p => true) %>" : error_messages_for(:node, :object => @node) }
          end
        rescue JSON::ParserError
          render :inline => _('could not save value (bad attribute)')
        end

        # Ajax table add row/column
        def table_update
          # get table
          @table = get_table_from_json(@node.prop[params[:attr]])
          # get row/cell
          table_data = @table[1]

          if params[:add] == 'row'
            table_data << table_data[0].map { ' ' }
          elsif params[:add] == 'column'
            table_data.each do |row|
              row << ' '
            end
          elsif params[:remove] == 'row' && table_data.size > 2
            table_data.pop
          elsif params[:remove] == 'column' && table_data[0].size > 1
            table_data.each do |row|
              row.pop
            end
          else
            # reorder ...
          end

          @node.update_attributes(params[:attr] => @table.to_json)
        rescue JSON::ParserError
          render :inline => _('could not save value (bad attribute)')
        end

      end

      Routes = {
        :cell_update => :post, :table_update => :post, :cell_edit => :get
      }

      module ViewMethods
        include Common

        # Create a table from an attribute
        def make_table(opts)
          style, node, attribute, title, table = opts[:style], opts[:node], opts[:attribute], opts[:title], opts[:table]
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

          if node.can_write?
            prefix << "<div class='table_add'>"
            prefix << link_to_remote("<img src='/images/column_add.png' alt='#{_('add column')}'/>",
                                      :url => "/nodes/#{node.zip}/table_update?add=column&attr=#{attribute}")
            prefix << link_to_remote("<img src='/images/column_delete.png' alt='#{_('add column')}'/>",
                                      :url => "/nodes/#{node.zip}/table_update?remove=column&attr=#{attribute}")
            prefix << link_to_remote("<img src='/images/row_add.png' alt='#{_('add column')}'/>",
                                      :url => "/nodes/#{node.zip}/table_update?add=row&attr=#{attribute}")
            prefix << link_to_remote("<img src='/images/row_delete.png' alt='#{_('add column')}'/>",
                                      :url => "/nodes/#{node.zip}/table_update?remove=row&attr=#{attribute}")
            prefix << "</div>"
          end

          table ||= get_table_from_json(node.prop[attribute])

          prefix + render_to_string( :partial=>'nodes/table', :locals => {
            :table     => table,
            :node      => node,
            :attribute => attribute
          }) + suffix
        rescue JSON::ParserError
          "<span class='unknownLink'>could not build table from text</span>"
        end
      end
    end # Grid
  end # Use
end # Zena
