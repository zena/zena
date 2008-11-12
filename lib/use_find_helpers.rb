module Zena
  module FindHelpers
    module UseFindHelpers
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend Zena::FindHelpers::TriggerClassMethod
      end
    end
    
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

      def next_zip(site_id)
        res = connection.update "UPDATE zips SET zip=@zip:=zip+1 WHERE site_id = '#{site_id}'"
        if res == 0
          # error
          raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
        end
        rows = connection.execute "SELECT @zip"
        rows.fetch_row[0].to_i
      end

      def fetch_attribute(attribute, sql)
        unless sql =~ /SELECT/i
          sql = "SELECT `#{attribute}` FROM #{table_name} WHERE #{sql}"
        end
        row = connection.execute(sql).fetch_row
        row ? row[0] : nil
      end
    end
    
    module TriggerClassMethod
      def use_find_helpers
        class_eval <<-END
          include Zena::FindHelpers::InstanceMethods
          class << self
            include Zena::FindHelpers::ClassMethods
          end
        END
      end
      
      # ...
    end
    
    module InstanceMethods
      # ...
    end
  end
end

ActiveRecord::Base.send :include, Zena::FindHelpers::UseFindHelpers
ActiveRecord::Base.send :use_find_helpers
