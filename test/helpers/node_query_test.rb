require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_test :node_basic #, :node_filters, :node_joins

  def parse(value, opts)
    login opts[:visitor].to_sym
    NodeQuery.new(value, opts).to_sql
  end

  make_tests
end