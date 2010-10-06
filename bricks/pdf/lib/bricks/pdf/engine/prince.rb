module Bricks
  module PDF
    module Engine
      module Prince
        def command(opts)
          cmd = ['prince']
          {
            :http_user     => '--http-user=',
            :http_password => '--http-password=',
            :baseurl       => '--baseurl='
          }.each do |key, cmd_key|
            cmd << "#{cmd_key}#{opts[key]}"
          end

          if file = opts[:input]
            cmd << file
          else
            cmd << "-"
          end

          if file = opts[:output]
            cmd << "-o #{file}"
          else
            cmd << "-o -"
          end

          cmd.join(' ')
        end
      end # Prince
    end # Engine
  end # PDF
end # Bricks



