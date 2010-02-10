module Dynamo
  module Serialization
    module Marshal

      def encode(data)
        ActiveSupport::Base64.encode64(::Marshal.dump(data)) if data
        #::Marshal.dump(data) if data
      end

      def decode(data)
        ::Marshal.load(ActiveSupport::Base64.decode64(data)) if data
        #::Marshal.load(data) if data
      end

    end # Marshal
  end # Serialization
end # Dynamo