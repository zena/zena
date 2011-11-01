module Zena
  module Use
    module MLIndex
      module ModelMethods
        def self.included(base)
          base.alias_method_chain :rebuild_index!, :multi_lingual
        end

        def rebuild_index_with_multi_lingual!
          visible_versions.each do |version|
            # 1. for each visible version
            self.version = version
            @properties  = version.prop
            # rebuild for each lang
            @index_langs = nil
            # Forces a to skip multi lingual indices
            # @index_langs = []

            # Build std index
            rebuild_index_for_version(version)
            rebuild_index_without_multi_lingual!
            # 2. PropEval::rebuild_index!
            # 3. Fulltext::rebuild_index!
            # 4. Properties::rebuild_index!
          end
        end

        def rebuild_index_for_version(v)
          # noop (method chaining in PropEval, Fulltext, etc)
        end


        # Hash used to read current values
        def index_reader(group_name)
          if group_name =~ /^ml_/
            return nil if index_langs.empty?
            super.merge(:with => {'lang' => index_langs})
          else
            super
          end
        end

        private
          # Return the list of languages for which the current version is returned.
          def index_langs
            @index_langs ||= begin
              v_id     = version.id
              ref_lang = self.ref_lang
              read     = vhash['w'].merge(vhash['r'])
              current_site.lang_list.select do |lang|
                (read[lang] || read[ref_lang] || read.values.first) == v_id
              end
            end
          end
      end # ModelMethods

      module SiteMethods
        def self.included(base)
          base.before_save :rebuild_index_on_lang_list_change
        end

        protected
          def rebuild_index_on_lang_list_change
            if languages_changed?
              # delete all ml entries for this site and rebuild
              Zena::Db.execute "DELETE idx FROM idx_nodes_ml_strings idx INNER JOIN nodes ON idx.node_id = nodes.id WHERE nodes.site_id = #{self[:id]}"
              rebuild_index
            end
          end
      end # SiteMethods
    end # MLIndex
  end # Use
end # Zena