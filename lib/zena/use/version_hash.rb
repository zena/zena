module Zena
  module Use
    # This module takes care of deciding which version should be seen by whom (depending on access rights
    # and language) by maintaining a 'vhash' entry. This module is also responsible for preloading versions
    # during 'many' finds.
    #
    # Technically, the vhash field contains two dictionaries "readonly" and "write". Each of these dictionaries
    # provide mapping from languages to version id.
    #
    #     {'r' => {'en' => 1234, 'fr' => 3456}, 'w' => {'en' => 5436, 'fr' => 4526}}
    module VersionHash
      def self.cached_values_from_records(records)
        r_hash, w_hash = {}, {}
        vhash = {'r' => r_hash, 'w' => w_hash}
        lang  = nil
        n_pub = nil
        records.each do |record|
          if record['lang'] != lang
            lang   = record['lang']
            # highest status for this lang
            if record['status'].to_i == Zena::Status::Pub
              # ok for readers & writers
              w_hash[lang] = r_hash[lang] = record['id'].to_i
              v_pub = record['publish_from']

              if v_pub.kind_of?(String)
                v_pub = DateTime.parse(record['publish_from']) rescue Time.now
              end

              if n_pub.nil? || v_pub < n_pub
                n_pub = v_pub
              end
            else
              # too high, only ok for writers
              w_hash[lang] = record['id'].to_i
            end
          elsif record['status'].to_i == Zena::Status::Pub
            # ok for readers
            r_hash[lang] = record['id'].to_i
            v_pub = DateTime.parse(record['publish_from']) rescue Time.now
            if n_pub.nil? || v_pub < n_pub
              n_pub = v_pub
            end
          end
        end
        {:publish_from => n_pub, :vhash => vhash}
      end

      module ModelMethods
        def version
          @version ||= begin
            if v_id = version_id
              version = ::Version.find(v_id)
            else
              version = ::Version.new
            end
            version.node = self
            version
          end
        end

        def version_id
          access = can_see_redactions? ? vhash['w'] : vhash['r']
          access[visitor.lang] || access[self[:ref_lang]] || access.values.first
        end

        # Return the list of versions that are stored in the vhash and could be loaded depending
        # on the visitor.
        def visible_versions
          @visible_versions ||= begin
            ids = (vhash['w'].values + vhash['r'].values).uniq
            ::Version.find(ids).tap do |list|
              list.each do |version|
                version.node = self
              end
            end
          end
        end

        def vhash
          @vhash ||= JSON.parse(self[:vhash] || '{"r":{}, "w":{}}')
        end

        def rebuild_vhash
          cached = VersionHash.cached_values_from_records(connection.select_all("SELECT id,lang,status,publish_from FROM #{Version.table_name} WHERE node_id = #{self.id} ORDER BY lang ASC, status DESC", "Version Load"))
          # We also rebuild publish_from here: yes, that's a leak with Workflow.
          self[:publish_from] = cached[:publish_from]
          self[:vhash] = cached[:vhash].to_json
          @vhash = cached[:vhash]
        end

        private
          def update_vhash
            version = self.version

            case @current_transition[:name]
            when :edit, :redit
              vhash['w'][version.lang] = version.id
            when :publish, :auto_publish
              vhash['r'][version.lang] = vhash['w'][version.lang] = version.id
            when :unpublish
              vhash['r'].delete(version.lang)
            when :remove
              if v_id = vhash['r'][version.lang]
                vhash['w'][version.lang] = v_id
              end
            when :destroy_version
              v_id = version.id
              lang = version.lang
              if vhash['w'][lang] == v_id
                # Writers were looking at old version
                if vhash['r'][lang] && vhash['r'][lang] != v_id
                  # There is a publication that can be used
                  vhash['w'][lang] = v_id
                else
                  # Nothing to see here for this lang
                  vhash['w'].delete(lang)
                  vhash['r'].delete(lang)
                end
              end

              if vhash['w'].values == []
                if last = versions.last
                  # We have a last version (not destroying node)
                  vhash['w'][last.lang] = last.id
                end
              end

              # force reload
              @version = nil
            end
            self[:vhash] = vhash.to_json
          end

          # Overwrite MultiVersion. This is called before update.
          def set_current_version_before_update
            super
            update_vhash
          end

          # Overwrite MultiVersion. This is called after create.
          def set_current_version_after_create
            update_vhash
            Zena::Db.set_attribute(self, :vhash, self[:vhash])
          end

          # Overwrite MultiVersion. This is called after a version is destroyed.
          def version_destroyed
            super
            rebuild_vhash
          end

      end # ModelMethods
    end # VersionHash
  end
end