require 'active_support'
require 'zena/remote/interface'
require 'zena/remote/klass'
require 'zena/remote/node'
require 'zena/remote/connection'

module Zena
  module Remote
    extend self

    # Create a new connection to a remote Zena application
    def connect(uri, token)
      Connection.connect(uri, token)
    end
  end # Remote
end # Zena