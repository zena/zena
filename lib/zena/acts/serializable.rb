#require 'active_record/xml_serializer'

module Zena
  module Acts
    module Serializable
      class PropertyAttribute < ActiveRecord::XmlSerializer::Attribute
        attr_accessor :raw_value

        def initialize(name, record, value)
          @raw_value  = value
          super(name, record)
        end

        protected

          def raw_value
            @raw_value ||= @record.prop[name]
          end

          def compute_value
            value = raw_value

            if formatter = Hash::XML_FORMATTING[type.to_s]
              value ? formatter.call(value) : nil
            else
              value
            end
          end

          def compute_type
            Hash::XML_TYPE_NAMES[raw_value.class.name] || :string
          end
      end # PropertyAttribute

      class IdAttribute < ActiveRecord::XmlSerializer::Attribute
        attr_accessor :raw_value

        def initialize(name, record, value)
          @raw_value  = value.kind_of?(Array) ? value.join(',') : value
          super(name, record)
        end

        def compute_value
          value = raw_value

          if formatter = Hash::XML_FORMATTING[type.to_s]
            value ? formatter.call(value) : nil
          else
            value
          end
        end

        def compute_type
          Hash::XML_TYPE_NAMES[raw_value.class.name] || :string
        end
      end # IdAttribute

      class XmlNodeSerializer < ActiveRecord::XmlSerializer
        def add_attributes
          ( serializable_attributes          +
            serializable_method_attributes   +
            serializable_property_attributes +
            serializable_id_attributes
          ).each do |attribute|
            add_tag(attribute)
          end
        end

        def serializable_property_attributes
          Array(options[:properties]).map { |name, value| PropertyAttribute.new(name, @record, value) }
        end

        def serializable_id_attributes
          Array(options[:ids]).map { |name, value| IdAttribute.new(name, @record, value) }
        end
      end

      module ModelMethods
        def to_xml(options = {}, &block)
          options = default_serialization_options.merge(options)
          serializer = XmlNodeSerializer.new(self, options)
          block_given? ? serializer.to_s(&block) : serializer.to_s
        end

        def default_serialization_options
          { :only       => %w{created_at updated_at log_at event_at kpath ref_lang fullpath position},
            :methods    => %w{v_status klass},
            :properties => export_properties,
            :ids        => export_ids,
            :dasherize  => false,
            :root       => 'node',
          }
        end

        def export_properties
          load_roles!
          res  = {}
          prop = self.prop
          schema.column_names.each do |key|
            next if key == 'cached_role_ids' # FIXME: use a flag to mark as non-exportable
            value = prop[key]
            next if value.blank?
            res[key] = value
          end
          res
        end

        def export_ids
          {'id' => zip}.merge(all_link_ids)
        end

        def all_link_ids
          res   = {}
          roles = {}

          sql = [%Q{SELECT nodes.zip, links.relation_id, links.source_id FROM nodes,links WHERE ((nodes.id = links.target_id AND links.source_id = ?) OR (nodes.id = links.source_id AND links.target_id = ?) OR (nodes.id = ? AND links.id = 0)) AND #{secure_scope('nodes')}}, self.id, self.id, self.parent_id]

          Zena::Db.select_all(sql).each do |record|
            if record['relation_id'].to_i > 0
              (roles[record['relation_id']] ||= []) << record
            else
              res["parent_id"] = record['zip']
            end
          end

          roles.each do |relation_id, records|
            relation = secure(Relation) { Relation.find(relation_id) }
            records.each do |record|
              if record['source_id'].to_i == id
                if relation.target_unique?
                  res["#{relation[:target_role]}_id"] = record['zip']
                else
                  (res["#{relation[:target_role]}_ids"] ||= []) << record['zip']
                end
              else
                if relation.source_unique?
                  res["#{relation[:source_role]}_id"] = record['zip']
                else
                  (res["#{relation[:source_role]}_ids"] ||= []) << record['zip']
                end
              end
            end
          end

          res
        end
      end # ModelMethods
    end # Serializable
  end # Acts
end # Zena