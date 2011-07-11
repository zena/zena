module Zena
  # This module is used to declare and manage the list of features used by Zena.
  module Use
    SUFFIX_NAME  = 'Methods'
    MODULE_NAMES = %w{Controller View Zafu User Site Skin}
    # "Controller" => "ControllerMethods"
    MODULE_NAME  = Hash[*MODULE_NAMES.map {|n| [n, "#{n}#{SUFFIX_NAME}"]}.flatten]

    class << self
      attr_accessor :modules

      # Declare a module (or list of modules) that should be used in Zena. The module should implement
      # sub-modules named ControllerMethods, ViewMethods or ZafuMethods in order to add features to
      # the controller, view or zafu compiler respectively.
      def module(*modules)
        create_module_hash

        modules.flatten.each do |mod|
          MODULE_NAME.each do |key, sub_module_name|
            begin
              self.modules[key] << mod.const_get(sub_module_name)
            rescue NameError
              # ignore
            end
          end
        end
      end

      def each_module_for(name)
        create_module_hash
        modules_for(name).each do |mod|
          yield(mod)
        end
      end

      def modules_for(name)
        create_module_hash
        self.modules[name] || []
      end

      private
        def create_module_hash
          if self.modules.nil?
            modules = (self.modules = {})
            MODULE_NAME.each do |key, value|
              modules[key] = []
            end
          end
        end
    end
  end
end
