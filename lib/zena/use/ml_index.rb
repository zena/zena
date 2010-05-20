module Zena
  module Use
    module MLIndex
      module ModelMethods
        def index_table_name(group_name)
          if group_name.to_s =~ /^ml_(.+)$/
            "i_#{$1}_#{self.class.table_name}"
          else
            super
          end
        end

        # Hash used to read current values
        def index_reader
          # FIXME: only insert lang if multilingual (include group_name as argument ?)!
          super.merge(:with => {'lang' => index_langs})
        end

        private
          def index_langs
            v_id = version.id
            ref_lang = self.ref_lang
            read = vhash['w'].merge(vhash['r'])
            @index_langs ||= current_site.lang_list.select do |lang|
              (read[lang] || read[ref_lang] || read.values.first) == v_id
            end.tap {|x| deb x}
          end
      end # ModelMethods
    end # MLIndex
  end # Use
end # Zena