module Zena
  module Use
    module MLIndex
      module ModelMethods
        def self.included(base)
          base.alias_method_chain :rebuild_index!, :multi_lingual
        end

        def rebuild_index_with_multi_lingual!
          # We call rebuild_index_without_multi_lingual first with our hack
          # to avoid inclusion order probles with fulltext index.

          # Skip multi lingual indices
          @index_langs = []

          # Build std index
          rebuild_index_without_multi_lingual!

          # Skip std index
          @skip_std_index = true

          visible_versions.each do |version|
            self.version = version
            @properties  = version.prop
            @index_langs = nil # force rebuild
            property_index
          end
        end

        # Hash used to read current values
        def index_reader(group_name)
          if group_name =~ /^ml_/
            return nil if index_langs.empty?
            super.merge(:with => {'lang' => index_langs})
          elsif @skip_std_index
            nil
          else
            super
          end
        end

        private
          def index_langs
            @index_langs ||= begin
              v_id = version.id
              ref_lang = self.ref_lang
              read = vhash['w'].merge(vhash['r'])
              current_site.lang_list.select do |lang|
                (read[lang] || read[ref_lang] || read.values.first) == v_id
              end
            end
          end
      end # ModelMethods
    end # MLIndex
  end # Use
end # Zena