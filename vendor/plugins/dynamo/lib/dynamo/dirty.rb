module Dynamo
  module Dirty

    # This method implement ActiveRecord::Dirty fonctionalities with Dynamo attributes.
    #
    # class Version
    #   include Dynamo::Attribute
    # end
    #
    # version = Version.create({'title'=>'test', 'foo'=>'bar', 'tic'=>'tac'})

    def dynamo_changed?
      !changed_dynamos.empty?
    end

    def dynamo_changed
      changed_dynamos.keys.sort
    end

    def dynamo_changes
      changed_dynamos
    end

    private

      def self.included(base)
        base.class_eval do
          alias_method_chain :changed?, :dynamo
          alias_method_chain :changed,  :dynamo
          alias_method_chain :changes,  :dynamo
        end
      end

      def changed_with_dynamo?
        changed_without_dynamo? || dynamo_changed?
      end

      def changed_with_dynamo
        changed_without_dynamo + dynamo_changed
      end

      def changes_with_dynamo
        changes_without_dynamo.merge(changed_dynamos)
      end

      def changed_dynamos
        original_dynamo = decode(read_attribute('dynamo'))
        dynamo_changed = {}

        #look for updated value
        if dynamo && original_dynamo
          dynamo.each do |dynamo,new_value|
            if new_value != old_value = original_dynamo.delete(dynamo)
              dynamo_changed[dynamo] = [old_value, new_value]
            end
          end
        end

        #look for deleted value
        if original_dynamo
          original_dynamo.each do |old_dynamo, old_value|
            dynamo_changed[old_dynamo] = [old_value, '']
          end
        end

        dynamo_changed
      end
  end # Dirty
end # Dynamo