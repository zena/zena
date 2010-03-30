require 'test_helper'

class QueryNodeTest < Zena::Unit::TestCase
  Compiler = Zena::Use::QueryNode::Compiler
  Query = QueryBuilder::Query

  context 'A class with QueryNode::ModelMethods included' do
    setup do
      login(:tiger)
    end

    subject do
      Node
    end

    should 'return compiler class on query_compiler' do
      assert_equal Compiler, subject.query_compiler
    end

    should 'return a query object on build_query' do
      assert_kind_of Query, subject.build_query(:all, 'nodes')
    end

  end
end