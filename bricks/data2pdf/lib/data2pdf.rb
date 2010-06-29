=begin rdoc
  Data2pdf is module to render file or IO streams (strings obviously) into pdf.

  Examples:

  Data.engine = 'Xhtml2pdf'

  Data2pdf.render "myfile.html"                          => STDOUT       (strings)
  Data2pdf.render "myfile.html", "out.pdf"               => out.pdf      (file)

  Data2pdf.render "This is text to render."              => STDOUT       (strings)
  Data2pdf.render "This is text to render.", "out.pdf"   => out.pdf      (file)
=end

dir = File.dirname(__FILE__)
require File.join(dir, 'engines', 'xhtml2pdf')
require File.join(dir, 'engines', 'prince')

module Data2pdf

  mattr_accessor :engine

  class << self

    def render src, dest=nil, opt={}
      start_engine!
      src_cmd, src_type   = (source src)
      dest_cmd, dest_type = (destination dest)
      css                 = (stylesheet opt[:css])
      cmd = command(src_cmd, dest_cmd, css)
      puts cmd
      io = IO.popen cmd, "w+"
      io.puts(src) if src_type == IO
      io.close_write
      out = io.gets(nil) if dest_type == IO
      io.close

      case dest_type.to_s
      when "IO"   then out
      when "File" then dest
      end

    end

    private

      def command src, dest, sheets=nil
        "#{binary} #{sheets} #{src} #{dest}"
      end

      def start_engine!
        if engine_module = const_get(engine.to_s.capitalize)
          extend engine_module
        end
      end

  end


end