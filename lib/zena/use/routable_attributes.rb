=begin

Example:

class Foo < ActiveRecord::Base
  attr_public :foo, :bar, :baz
end

=end
module Zena
module Use
  module RoutableAttributes
    DEFAULT_ROUTE = Proc.new {|obj, hash| obj.attributes_without_routes = hash }
    
    def self.included(base)
      base.send :class_eval do
        @@_attr_route  ||= {} # defined for each class
        @@_attr_routes ||= {} # full list with inherited attributes
        alias :attributes_without_routes= :attributes=

        class << self
          def attr_route(hash)
            list = (@@_attr_route[self] ||= [])
            hash.each do |regex, proc|
              list.reject! do |k, v|
                k == regex
              end
              list << [regex, proc]
            end
          end

          # Return the list of all ordered routes, including routes defined in the superclass
          def attr_routes
            @@_attr_routes[self] ||= if superclass.respond_to?(:attr_routes)
              # merge with superclass attributes
              list = superclass.attr_routes.dup
              (@@_attr_route[self] || []).each do |regex, proc|
                list.reject! do |k, v|
                  k == regex
                end
                list << [regex, proc]
              end
              list
            else
              # top class, nothing to inherit
              @@_attr_route[self] || []
            end
          end
          
          def attr_route_for(at)
            attr_routes.each do |filter, proc|
              if filter.kind_of?(Regexp) && at =~ filter
                return [proc, $1]
              elsif filter.kind_of?(Array) && filter.include?(at)
                return [proc, at]
              end
            end
            # bad attribute
            nil
          end
        end
      
        def attributes=(hash)
          route_attributes(hash).each do |proc, attrs|
            proc.call(self, attrs)
          end
        end
        
        private
          def route_attributes(attributes)
            routes = {}
            attributes.each do |k,v|
              if self.respond_to?(:"#{k}=")
                routes[DEFAULT_ROUTE] ||= {}
                routes[DEFAULT_ROUTE][k] = v
                next
              end
              if res = self.class.attr_route_for(k)
                routes[res[0]] ||= {}
                routes[res[0]][res[1]] = v
              else
                # ignore bad attributes
              end
            end
            routes
          end
          
      end
    end
  end
end
end


=begin

# TODO: move tests in a proper test file
def assert_equal(exp,real)
  if exp != real
    puts "#{real.inspect} not equal to #{exp.inspect}"
  else
    print('.')
  end
end

class Base
  attr_writer :attributes
  include Zena::Use::RoutableAttributes
  attr_route 'b' => 'b'
  attr_route 'a' => 'a'
end

class Base2
  attr_writer :attributes
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
  attr_reader :attributes
  
  def attributes=(h)
    h.each do |k,v|
      @attributes[k] = "respond_to: #{v}"
    end
  end
  
  include Zena::Use::RoutableAttributes
  attr_route ['a','b','c'] => Proc.new {|obj,hash| obj.set_array(hash) }
  attr_route %r{^(a.*)}    => Proc.new {|obj,hash| obj.start_with_a(hash) }
  
  def name=
    #
  end
  
  def initialize(h)
    @attributes = {}
    self.attributes = h
  end
  
  def set_array(hash)
    hash.each do |k,v|
      @attributes[k] = "set_array: #{v}"
    end
  end
  
  def start_with_a(hash)
    hash.each do |k,v|
      @attributes[k] = "start_with_a: #{v}"
    end
  end
end


class SubDummy < Dummy
  attr_route %r{^(a.*)} => Proc.new {|obj,hash| obj.my_start_with_a(hash) }
  attr_route %r{^b(.*)} => Proc.new {|obj,hash| obj.b_prefix(hash) }
  
  def my_start_with_a(hash)
    hash.each do |k,v|
      @attributes[k] = "my_start_with_a: #{v}"
    end
  end
  
  def b_prefix(hash)
    hash.each do |k,v|
      @attributes[k] = "b_prefix: #{v}"
    end
  end
end

h = {"a"=>"set_array: a", "b"=>"set_array: b", "arm"=>"start_with_a: arm", 'name' => 'respond_to: name'}
assert_equal h, Dummy.new('a' => 'a', 'arm' => 'arm', 'b' => 'b', 'bolomey' => 'bolomey', 'name' => 'name').attributes

h = {"a"=>"set_array: a", "b"=>"set_array: b", "arm"=>"my_start_with_a: arm", 'name' => 'respond_to: name', 'olomey' => 'b_prefix: bolomey'}
assert_equal h, SubDummy.new('a' => 'a', 'arm' => 'arm', 'b' => 'b', 'bolomey' => 'bolomey', 'name' => 'name').attributes
=end