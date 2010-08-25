module Zena
  module Remote
    extend self

    # Create a new connection to a remote Zena application
    def connect(uri, token)
      Connection.connect(uri, token)
    end
  end # Remote
end # Zena