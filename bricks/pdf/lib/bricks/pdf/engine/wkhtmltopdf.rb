module Bricks
  module Pdf
    module Engine
      module Wkhtmltopdf
        CMD = Bricks::CONFIG['pdf']['cmd'] || 'wkhtmltopdf'
        def command(opts)
          cmd = [CMD]
          {
            :http_user     => '--username ',
            :http_password => '--password ',
            # No base url option in version 0.9.6.
            # Put a <base href="www.host.com/"/> at the beginning of the page
            #:baseurl       => '--baseurl='
          }.each do |key, cmd_key|
            cmd << "#{cmd_key}#{opts[key]}"
          end

          if file = opts[:input]
            cmd << file
          else
            cmd << "-"
          end

          if file = opts[:output]
            cmd << file
          else
            cmd << "-"
          end

          # FIXME: find a way to redirect errors on screen instead of main log.
          # Errors redirected to server log file.
          cmd << "2> #{Zena.log_path}"

          cmd.join(' ')
        end
      end # Prince
    end # Engine
  end # Pdf
end # Bricks




