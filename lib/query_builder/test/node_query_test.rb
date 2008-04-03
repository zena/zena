require File.join(File.dirname(__FILE__) , 'yaml_test.rb')

class NodeQueryTest < Test::Unit::TestCase
  yaml_test :node_basic #, :node_filters, :node_joins

  def parse(value)
    NodeQuery.new(value).to_sql
  end

  make_tests
end