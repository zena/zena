class StringHash < Hash
  include RubyLess
  safe_context [:[], String] => String
  safe_method :keys => [String]
end