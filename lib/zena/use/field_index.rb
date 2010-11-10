module Zena
  module Use
    module FieldIndex
      module ModelMethods
        def self.included(base)
          # Declare all columns starting with idx_ as field index
          ::Column.add_field_index(base.column_names.select {|col| col =~ /\Aidx_/})

#          base.alias_method_chain :property_field_index, :field_index
        end

        def property_field_index
          if version.status == Zena::Status[:pub]
            super
          end
        end
      end # ModelMethods
    end # FieldIndex
  end # Use
end # Zena