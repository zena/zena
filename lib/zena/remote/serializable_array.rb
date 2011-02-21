module Zena
  module Remote
    class SerializableArray < Array
      def initialize(name, elem_name, elements)
        @name, @elem_name = name, elem_name
        replace(elements)
      end

      def to_xml(opts)
        builder = opts[:builder]
        builder.tag!(@name, :type => :array) do
          each do |elem|
            builder.tag!(@elem_name, elem.to_s, :type => :string)
          end
        end
      end
    end
  end # Remote
end # Zena