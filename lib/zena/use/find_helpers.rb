# FIXME: ! this should go into Zena::Db !!!!

module Zena
  module Use
    module FindHelpers
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddUseFindHelpersMethod
      end
    end

    module AddUseFindHelpersMethod
      def use_find_helpers
        class_eval do
          class << self
            include Zena::Use::FindHelpersImpl::ClassMethods
          end
        end
      end
    end

    module FindHelpersImpl
      module ClassMethods
        def fetch_ids(sql, id_attr='id')
          unless sql =~ /SELECT/i
            sql = "SELECT `#{id_attr}` FROM #{self.table_name} WHERE #{sql}"
          end
          connection.select_all(sql, "#{name} Load").map! do |record|
            record[id_attr.to_s]
          end
        end

        def fetch_list(sql, *attr_list)
          unless sql =~ /SELECT/i
            sql = "SELECT #{attr_list.map {|a| "`#{a}`"}.join(', ')} FROM #{self.table_name} WHERE #{sql}"
          end
          connection.select_all(sql, "#{name} Load").map! do |record|
            Hash[*(attr_list.map {|attr| [attr, record[attr.to_s]] }.flatten)]
          end
        end

        # TODO: move this into Zena::Db
        def fetch_attribute(attribute, sql)
          unless sql =~ /SELECT/i
            sql = "SELECT `#{attribute}` FROM #{table_name} WHERE #{sql}"
          end
          Zena::Db.fetch_row(sql)
        end
      end
    end
  end
end
