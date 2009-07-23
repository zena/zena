=begin

Example:

class Foo < ActiveRecord::Base
  has_one :redaction
  attr_route /^v_(.*)/ => 'redaction'
end

=end
module Zena
module Use
  module RoutableAttributes
    DEFAULT_ROUTE = Proc.new {|obj, hash| obj.attributes_without_routes = hash }
    
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        alias_method :attributes_without_routes=, :attributes=
        alias_method :attributes=, :attributes_with_routes=
      end
    end
    
    module ClassMethods
      @@_attr_route  ||= {} # defined for each class
      @@_attr_routes ||= {} # full list with inherited attributes
      
      def attr_route(hash)
        list = (@@_attr_route[self] ||= [])
        hash.each do |regex, method|
          list.reject! do |k, v|
            k == regex
          end
          
          list << [regex, method]
        end
      end

      # Return the list of all ordered routes, including routes defined in the superclass
      def attr_routes
        @@_attr_routes[self] ||= if superclass.respond_to?(:attr_routes)
          # merge with superclass attributes
          list = superclass.attr_routes.dup
          (@@_attr_route[self] || []).each do |regex, method|
            list.reject! do |k, v|
              k == regex
            end
            list << [regex, method]
          end
          list
        else
          # top class, nothing to inherit
          @@_attr_route[self] || []
        end
      end
      
      def attr_route_for(at)
        attr_routes.each do |filter, method|
          if filter.kind_of?(Regexp) && at =~ filter
            return [method, $1]
          elsif filter.kind_of?(Array) && filter.include?(at)
            return [method, at]
          end
        end
        # bad attribute
        nil
      end
    end
    
    def attributes_with_routes=(attrs)
      self.attributes_without_routes = route_attributes(attrs)
    end
  
    private
      def route_attributes(attributes)
        routes = attributes.stringify_keys
        routes.keys.each do |k|
          if self.respond_to?(:"#{k}=")
            next
          end
          if res = self.class.attr_route_for(k)
            route, key = *res
            path = route.split('/')
            target = routes
            path.each do |p|
              target["#{p}_attributes"] ||= {}
              target = target["#{p}_attributes"]
            end
            target.reverse_merge!(res[1] => routes.delete(k))
          else
            # just keep it
          end
        end
        routes
      end
  end
end
end


=begin

# TODO: move tests in a proper test file
class Hash
  def reverse_merge!(other_hash)
    replace(other_hash.merge(self))
  end
  def stringify_keys
    res = {}
    keys.each do |key|
      res[key.to_s] = self[key]
    end
    res
  end
end
    
def assert_equal(exp,real)
  if exp != real
    puts "#{real.inspect} not equal to #{exp.inspect}"
  else
    print('.')
  end
end

class Base
  attr_writer :attributes
  def self.accepts_nested_attributes_for(*args); end
  include Zena::Use::RoutableAttributes
  attr_route 'b' => 'b'
  attr_route 'a' => 'a'
end

class Base2
  attr_writer :attributes
  def self.accepts_nested_attributes_for(*args); end
  include Zena::Use::RoutableAttributes
  attr_route 'b2' => 'b2'
end

class B < Base
  attr_route 'c' => 'c'
end

class B2 < Base2
  attr_route 'c2' => 'c2'
end

class C < B
  attr_route 'b' => 'c'
end

assert_equal [["b", "b"], ["a", "a"]],               Base.attr_routes
assert_equal [["b2", "b2"]],                         Base2.attr_routes
assert_equal [["b", "b"], ["a", "a"], ["c", "c"]],   B.attr_routes
assert_equal [["b2", "b2"], ["c2", "c2"]],           B2.attr_routes
assert_equal [["a", "a"], ["c", "c"], ["b", "c"]],   C.attr_routes





class Dummy
  attr_accessor :attributes
  def self.accepts_nested_attributes_for(*args); end
  
  include Zena::Use::RoutableAttributes
  attr_route ['a','b','c'] => 'array'
  attr_route %r{^(a.*)}    => 'start_with_a'
  
  def name=
    #
  end
  
  def initialize(h)
    @attributes = {}
    self.attributes = h
  end
end


class SubDummy < Dummy
  attr_route %r{^(a.*)} => 'my_start_with_a'
  attr_route %r{^b(.*)} => 'b_prefix'
  attr_route %r{^deep_(.*)} => 'b_prefix/deep'
end

h = {"name"=>"name", "array_attributes"=>{"a"=>"a", "b"=>"b"}, "start_with_a_attributes"=>{"arm"=>"arm"}, "bolomey" => "bolomey"}
assert_equal h, Dummy.new('a' => 'a', 'arm' => 'arm', 'b' => 'b', 'bolomey' => 'bolomey', 'name' => 'name').attributes

h = {"b_prefix_attributes"=>{"deep_attributes"=>{"data"=>"deep_data"}, "olomey"=>"bolomey"}, "name"=>"name", "array_attributes"=>{"a"=>"a", "b"=>"b"}, "my_start_with_a_attributes"=>{"arm"=>"arm", "set_before"=>"set_before"}}
assert_equal h, SubDummy.new('a' => 'a', 'arm' => 'arm', 'b' => 'b', 'bolomey' => 'bolomey', 'name' => 'name', 'deep_data' => 'deep_data', 'my_start_with_a_attributes' => {'set_before' => 'set_before'}).attributes

=end