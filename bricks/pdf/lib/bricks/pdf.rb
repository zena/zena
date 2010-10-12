=begin rdoc
  PDF is module to render file or IO streams (strings obviously) into pdf.

  Examples:

  Bricks::PDF.engine = 'Xhtml2pdf'

  Bricks::PDF.render_file "myfile.html"                            => STDOUT       (strings)
  Bricks::PDF.render_file "myfile.html", "out.pdf"                 => out.pdf      (file)

  Bricks::PDF.render_string "This is text to render."              => STDOUT       (strings)
  Bricks::PDF.render_string "This is text to render.", "out.pdf"   => out.pdf      (file)
=end

module Bricks
  module PDF
    extend self
    # Wrapper around pdf engines
    module Engine
    end # Engine

    class Error < Exception
    end

    # Raised when an argument is invalid
    class ArgumentError < Error
    end

    # Raised when the pdf engine could not be loaded
    class InvalidEngine < Error
    end

    def engine=(engine_name)
      engine_module = Zena.resolve_const("Bricks::PDF::Engine::#{engine_name.to_s.capitalize}")
      extend engine_module
    rescue NameError
      raise PDF::InvalidEngine, "Could not load pdf engine '#{engine_name}'."
    end

    def render(options)
      res = nil

      # TODO: redirect error messages...
      IO.popen(command(options), 'w+') do |io|

        if data = options[:data]
          io.puts(data)
        end
        io.close_write

        unless res = options[:output]
          res = io.gets
        end
      end

      res
    end

    module ControllerMethods
      def render_to_pdf(opts)
        # Get zafu template (compile if needed)
        template_path = template_url(opts)

        # Produce html
        data = render_to_string(:file => template_path, :layout=>false)

        target_file = Tempfile.new('trg').path + '.pdf'

        data = Bricks::PDF.render(get_render_auth_params.merge(
          :data   => data,
          :output => target_file
        ))

        if File.exist?(target_file)
          data = nil

          File.open(target_file, 'rb') do |f|
            data = f.read
          end

          FileUtils.rm(target_file)
          {
            :type        => 'application/pdf',
            :disposition => params['disposition'] || 'inline',
            # Compile html to pdf
            :data        => data
          }
        else
          # did not work
          {
            :type        => 'text/html',
            # Compile html to pdf
            :disposition => 'inline',
            :data        => "Could not render pdf file..."
          }
        end
      end
    end # ControllerMethods

    module ZafuMethods
    end # ZafuMethods
  end # PDF
end # Bricks