require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_dir  File.join(File.dirname(__FILE__), 'node_query')
  yaml_test :basic, :filters, :relations

  def parse(value, opts)
    login opts[:visitor].to_sym
    NodeQuery.new(value, opts).to_sql
  end

  make_tests
end