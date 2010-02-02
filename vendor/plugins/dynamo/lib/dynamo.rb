begin
  dir = File.dirname(__FILE__)
  require "#{dir}/dynamo/attribute"
  require "#{dir}/dynamo/dirty"
  require "#{dir}/dynamo/property"
  require "#{dir}/dynamo/declaration"
  require "#{dir}/serialization/yaml"
  require "#{dir}/serialization/marshal"
end
