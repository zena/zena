module Zena
  module Use
    # This module takes care of deciding which version should be seen by whom (depending on access rights
    # and language) by maintaining a 'vhash' entry. This module is also responsible for preloading versions
    # during 'many' finds.
    #
    # Technically, the vhash field contains two dictionaries "readonly" and "write". Each of these dictionaries
    # provide mapping from languages to version id.
    module VersionHash

      class << self
        def cached_values_from_records(records)
          r_hash, w_hash = {}, {}
          vhash = {'r' => r_hash, 'w' => w_hash}
          lang  = nil
          n_pub = nil
          records.each do |record|
            if record['lang'] != lang
              lang   = record['lang']
              # highest status for this lang
              if record['status'].to_i == Zena::Status[:pub]
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
            elsif record['status'].to_i == Zena::Status[:pub]
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
      end

      def version_id
        access = can_see_redactions? ? vhash['w'] : vhash['r']
        access[visitor.lang] || access[ref_lang] || access.values.first
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
          end
          self[:vhash] = vhash.to_json
        end

        # Overwrite MultiVersion. This is called before update.
        def current_version_before_update
          super
          update_vhash
        end

        # Overwrite MultiVersion. This is called after create.
        def current_version_after_create
          update_vhash
          Zena::Db.set_attribute(self, :vhash, self[:vhash])
        end

        # Overwrite MultiVersion. This is called after a version is destroyed.
        def version_destroyed
          super
          rebuild_vhash
        end
    end
  end
end