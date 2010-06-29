module Data2pdf
  module Xhtml2pdf

    def binary
      'pisa'
    end

    def stylesheet sheet
      #sheets.flatten.inject(""){|str,sheet| str + "--css=#{sheet.to_s} " } unless sheets.first.nil?
      "--css=#{sheet.to_s}" unless sheet.nil? || sheet==""
    end

    def source src
      case
      when File.exist?(src)
        [src, File]
      when src =~ /^http/
        [src, URI]
      when src.kind_of?(String)
        ["-", IO]
      else
        raise ArgumentError, "Source is invalid.", caller
      end
    end

    def destination dest
      case
      when dest.is_a?(String)
        [dest, File]
      when dest.nil?
        ["-", IO]
      else
        raise ArgumentError, "Destination is invalid.", caller
      end
    end

  end
end



