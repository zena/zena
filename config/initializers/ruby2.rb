
  module I18n
    module Backend
      module Base
        def load_file(filename)
          type = File.extname(filename).tr('.', '').downcase
          # As a fix added second argument as true to respond_to? method
          raise UnknownFileType.new(type, filename) unless respond_to?(:"load_#{type}", true)
          data = send(:"load_#{type}", filename) # TODO raise a meaningful exception if this does not yield a Hash
          data.each { |locale, d| store_translations(locale, d) }
        end
      end
    end
  end
