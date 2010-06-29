module Data2pdf
  module Prince

    def binary
      "prince"
    end

    def stylesheet sheet
      #sheets.flatten.inject(""){|str,sheet| str + "--style=#{sheet} " } unless sheets.first.nil?
      "-s #{sheet}" unless sheet.nil? || sheet == ""
    end

    def source src
      case
      when File.exist?(src)
        [src, File]
      when src.kind_of?(String)
        ["-", IO]
      else
        raise ArgumentError, "Source is invalid.", caller
      end
    end

    def destination dest
      case
      when dest.is_a?(String)
        ["-o #{dest}", File]
      when dest.nil?
        ["-o -", IO]
      else
        raise ArgumentError, "Destination is invalid.", caller
      end
    end

  end
end



