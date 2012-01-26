require 'simple_xlsx'
require 'fileutils'
=begin rdoc
  Spreadsheet is module to create spreadsheet documents (csv or xlsx).

=end
module Bricks
  module Spreadsheet
    # Wrappers to expose rendering engine to RubyLess.
    class Row
      attr_reader :cells
      include RubyLess
      # we use Zafu to declare <r:cell>. See r_cell below.

      def initialize
        @cells = []
      end

      def cell(value)
        @cells << (value || '')
        "#{value};"
      end
    end

    class Head < Row
    end

    class Sheet
      attr_reader :rows, :name
      def initialize(name)
        @name = name
        @rows = []
      end

      def row
        row = Row.new
        @rows << row
        row
      end

      def head
        row = Head.new
        @rows << row
        row
      end
    end

    class Document
      def initialize
        @sheets = []
      end

      def sheet(name)
        if name.kind_of?(Hash)
          name = name[:name]
        end
        s = Sheet.new(name || 'Sheet1')
        @sheets << s
        s
      end

      def render_xlsx
        tmpf = Tempfile.new('output.xlsx')
        tmpf.close
        # Zip does not want the file to exist beforehand.
        path = tmpf.path
        FileUtils.rm(path)
        SimpleXlsx::Serializer.new(path) do |doc|
          @sheets.each do |s|
            doc.add_sheet(s.name) do |sheet|
              s.rows.each do |r|
                sheet.add_row r.cells
              end # each row
            end
          end # each @sheet
        end
        File.open(path, 'rb') { |file| file.read }
      end

      def render_html
        html = []
        @sheets.each do |s|
          html << '<table>'
          s.rows.each do |r|
            html << '<tr>'
            r.cells.each do |c|
              html << "<td>#{escape_html(c)}</td>"
            end
            html << '</tr>'
          end # each row
          html << '</table>'
        end # each @sheet
        html.join("\n")
      end

      def render_csv
        csv = ''
        @sheets.each_with_index do |s, i|
          if i > 1
            csv << "\n\n"
          end
          s.rows.each do |r|
            r.cells.each do |c|
              csv << "#{escape_csv(c)};"
            end
            csv << "\n"
          end # each row
        end # each @sheet
        csv
      end

      def escape_csv(val)
        if val =~ /[\n;]/
          val.to_s.inspect
        else
          val.to_s
        end
      end

      def escape_html(val)
        val.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end
    end

    module ControllerMethods
      def render_to_csv(opts)
        render_spreadsheet(opts, :csv)
      end

      def render_to_xlsx(opts)
        render_spreadsheet(opts, :xlsx)
      end

      def render_spreadsheet(opts, type)
        if params[:debug]
          type = :html
        end
        # Get zafu template (compile if needed)
        if opts[:inline]
          # This is used during testing
        else
          template_path = template_url(opts)
        end

        # temporary file
        @spreadsheet = Bricks::Spreadsheet::Document.new

        if opts[:inline]
          err = render_to_string(:inline => opts[:inline])
        else
          err = render_to_string(:file => template_path, :layout=>false)
        end

        if err =~ /parser_error/
          data = err
          type = :html
        end

        begin
          if type == :xlsx
            {
              :data        => @spreadsheet.render_xlsx,
              :type        => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              :disposition => 'attachment',
            }
          elsif type == :csv
            {
              :data        => @spreadsheet.render_csv,
              :type        => 'text/csv',
              :disposition => 'attachment',
            }
          else
            data = data || @spreadsheet.render_html
            {
              :data        => %Q{
<html>
<head>
</head>
<style>
body {padding:10px;}
table {border-collapse:collapse}
td{border:1px solid #444; padding:2px;}
.parser_error {border:1px solid red; background:#fee; color:#333;}
.parser_error .method { background:#faa; padding:0 2px;}
</style>
</head>
<body>
<h1>Render as #{type}</h1>
#{data}
</body>
</html>
              },
              :type        => 'text/html',
              :disposition => 'inline',
            }
          end
        rescue => err
          {
            :data        => %Q{<html><head></head><body><h1>Could not render #{type}</h1>\n#{data}<pre>#{err}\n#{err.backtrace[0..8].join("\n")}</pre></body></html>},
            :type        => 'text/html',
            :disposition => 'inline',
          }
        end
      end
    end # ControllerMethods

    module ZafuMethods
      def r_spreadsheet
        # Enter xlsx context.
        r = get_var_name('spreadsheet', 'doc')
        set_context_var('spreadsheet', 'doc', RubyLess::TypedString.new(
          r,
          :class => Bricks::Spreadsheet::Document
        ))
        expand_if("#{r} = @spreadsheet")
      end

      def r_sheet
        if doc = get_context_var('spreadsheet', 'doc')
          s = get_var_name('spreadsheet', 'sheet')
          if name = @params[:name]
            code = RubyLess.translate_string(self, name)
          else
            code = ''
          end
          out "<% #{s} = #{doc}.sheet(#{code}) %>"
          set_context_var('spreadsheet', 'sheet', RubyLess::TypedString.new(
            s,
            :class => Bricks::Spreadsheet::Sheet
          ))
          expand_with
        else
          parser_error("Should only be called in a spreadsheet context.")
        end
      end

      def r_row
        if sheet = get_context_var('spreadsheet', 'sheet')
          r = get_var_name('spreadsheet', 'row')
          out "<% #{r} = #{sheet}.row %>"
          set_context_var('spreadsheet', 'row', RubyLess::TypedString.new(
            r,
            :class => Bricks::Spreadsheet::Row
          ))
          expand_with
        else
          parser_error("Should only be called in a spreadsheet/sheet context.")
        end
      end

      def r_head
        if sheet = get_context_var('spreadsheet', 'sheet')
          r = get_var_name('spreadsheet', 'head')
          out "<% #{r} = #{sheet}.head %>"
          set_context_var('spreadsheet', 'row', RubyLess::TypedString.new(
            r,
            :class => Bricks::Spreadsheet::Head
          ))
          expand_with
        else
          parser_error("Should only be called in a spreadsheet/sheet context.")
        end
      end

      def r_cell
        if row = get_context_var('spreadsheet', 'row')
          code = get_attribute_or_eval
          if not code
            code = get_var_name('spreadsheet', 'cell')
            out "<% #{code} = capture do %>"
            out expand_with
            out "<% end %>"
          end
          out "<% #{row}.cell(#{code}) %>"
        else
          parser_error("Should only be called in a spreadsheet/sheet/row context.")
        end
      end
    end # ZafuMethods
  end # Spreadsheet
end # Bricks