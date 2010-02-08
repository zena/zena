module Zena
  module Refactor
    module Version
      def self.included(base)
        class << base
          def content_class
            nil
          end
        end
      end

      def setup_version_on_create
        # set number
        last_record = self[:node_id] ? self.connection.select_one("select number from #{self.class.table_name} where node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1") : nil
        self[:number] = (last_record || {})['number'].to_i + 1

        # set author
        self[:user_id] = visitor.id
        self[:lang]    = visitor.lang unless lang_changed?
        self[:site_id] = current_site.id
      end
    end
  end
end