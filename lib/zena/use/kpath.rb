module Zena
  module Use
    module Kpath
      module ClassMethods
        # kpath selector for the current class
        def ksel
          self.to_s[0..0]
        end
        
        # Replace Rails subclasses normal behavior
        def type_condition
          " #{table_name}.kpath LIKE '#{kpath}%' "
        end
      end # ClassMethods
      
      module InstanceMethods
        def self.included(base)
          base.class_eval do
            extend ClassMethods
            
            before_validation :set_kpath
          end
          
          class << base
            # The kpath must be set in the class's metaclass so that each sub-class has its own
            # @kpath.
            
            # kpath is a class shortcut to avoid tons of 'OR type = Page OR type = Document'
            # we build this path with the first letter of each class. The example bellow
            # shows how the kpath is built:
            #           class hierarchy
            #                Node --> N
            #       Note --> NN          Page --> NP
            #                    Document   Form   Section
            #                       NPD      NPF      NPP
            # So now, to get all Pages, your sql becomes : WHERE kpath LIKE 'NP%'
            # to get all Documents : WHERE kpath LIKE 'NPD%'
            # all pages without Documents : WHERE kpath LIKE 'NP%' AND NOT LIKE 'NPD%'
            attr_accessor :kpath

            def kpath
              @kpath ||= make_kpath
            end

            private
              def make_kpath
                superclass.respond_to?(:kpath) ? (superclass.kpath + ksel) : ksel
              end
          end
        end
        
        private
          def set_kpath
            self[:kpath] = self.vclass.kpath if vclass_id_changed? or type_changed?
            true
          end
      end # InstanceMethods
    end # Kpath
  end # Use
end # Zena