module Zena
  module Use
    module MLIndex
      module ModelMethods
        # Hash used to read current values
        def index_reader(group_name)
          if group_name.to_s =~ /^ml_/
            super.merge(:with => {'lang' => index_langs})
          else
            super
          end
        end

        private
          def index_langs
            v_id = version.id
            ref_lang = self.ref_lang
            read = vhash['w'].merge(vhash['r'])
            @index_langs ||= current_site.lang_list.select do |lang|
              (read[lang] || read[ref_lang] || read.values.first) == v_id
            end
          end
      end # ModelMethods
    end # MLIndex
  end # Use
end # Zena