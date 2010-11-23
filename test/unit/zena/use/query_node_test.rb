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

    should 'implement db_attr' do
      assert subject.new.respond_to?(:db_attr)
    end

    should 'declare db_attr as safe RubyLess' do
      assert_equal Hash[:class => Zena::Use::QueryNode::StringDictionary, :method => 'db_attr'],
        subject.safe_method_type(['db_attr'])
    end

    should 'declare first as safe RubyLess' do
      assert_equal Hash[:class => Node, :method => 'safe_first', :nil => true],
        subject.safe_method_type(['first', String])
      assert_kind_of Image, subject.new.safe_eval('first("image in site")')
    end
  end # A class with QueryNode::ModelMethods included

  context 'An object with QueryNode::ModelMethods' do

    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:status) }
    end

    should 'return an empty hash on db_attr' do
      assert_nothing_raised do
        assert_equal Hash[], subject.db_attr
      end
    end

    context 'found with an SQL query' do
      subject do
        secure!(Node) { Node.first(
          :select     => 'count(versions.id) AS versions_count',
          :joins      => 'LEFT JOIN versions ON versions.node_id = nodes.id',
          :conditions => {'nodes.id' => nodes_id(:status)})
        }
      end

      should 'reflect AS from query in db_attr' do
        assert_equal Hash['versions_count', '2'], subject.db_attr
      end
    end

    should 'return an array on find all' do
      assert_kind_of Array, subject.find(:all, 'images in site')
    end

    should 'return a record on find first' do
      assert_kind_of Node, subject.find(:first, 'images in site')
    end

    should 'return a number on find count' do
      assert_equal 4, subject.find(:count, 'images in site')
    end
  end # An object with QueryNode::ModelMethods

  context 'Building a query' do
    context 'with a real class filter' do
      subject do
        Node.build_query(:all, 'documents')
      end

      should 'set main_class' do
        assert_equal VirtualClass['Document'], subject.main_class
      end
    end # with a real class filter

    context 'with root' do
      subject do
        Node.build_query(:all, 'root')
      end

      should 'set main_class to Project' do
        assert subject.main_class <= Project
      end
    end # with a real class filter

    context 'with a virtual class filter' do
      subject do
        Node.build_query(:all, 'letters')
      end

      should 'set main_class with real_class' do
        assert_equal VirtualClass['Letter'], subject.main_class
        assert subject.main_class < Note
      end

      should 'load roles' do
        assert subject.main_class.safe_method_type(['assigned'])
      end

      should 'set kpath' do
        assert_equal 'NNL', subject.main_class.kpath
      end
    end # with real class filter
  end # Building a query
end