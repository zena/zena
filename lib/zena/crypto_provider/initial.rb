module Zena
  module CryptoProvider
    class Initial
      def self.encrypt(*tokens)
        # encrypt password (old bad method: SHA1, no stretching, no per-password salt)
        Digest::SHA1.hexdigest((tokens.flatten.shift || '') + PASSWORD_SALT)
      end

      def self.matches?(crypted_password, *tokens)
        # return true if the tokens match the crypted_password
        encrypt(*tokens) == crypted_password
      end
    end
  end
end