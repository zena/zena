=begin

Example:

class Foo < ActiveRecord::Base
  attr_public :foo, :bar, :baz
end

=end
module Zena
module Use
  module PublicAttributes
    
    def self.included(base)
      base.send :class_eval do
        @@_attr_public       ||= {} # defined for each class
        @@_public_attributes ||= {} # full list with inherited attributes

        class << self
          def attr_public(*list)
            @@_attr_public[self] ||= []
            @@_attr_public[self] = (@@_attr_public[self] + list.map{|l| l.to_s}).uniq
          end
        
          # Return the list of all attributes safe for reading, including attributes defined in the superclass
          def public_attributes
            @@_public_attributes[self] ||= if superclass.respond_to?(:public_attributes)
              # merge with superclass attributes
              (superclass.public_attributes + (@@_attr_public[self] || [])).uniq.sort
            else
              # top class, nothing to inherit
              @@_attr_public[self] || []
            end
          end
          
          # Return true if the attribute can be safely read
          def attr_public?(key)
            public_attributes.include?(key.to_s)
          end
        end
      end
      
      # Safe attribute reader used when 'safe_readable?' could not be called because the class
      # is not known during compile time.
      def public_read(key)
        return "'#{key}' not readable" unless self.class.attr_public?(key)
        self.send(key)
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
  include Zena::Use::PublicAttributes
end

class Base2
  include Zena::Use::PublicAttributes
end

class B < Base
  attr_public :b_r1, :b_r2
end

class B2 < Base2
  attr_public :b2_a1
end

class C < B
  attr_public :c_a1
end

assert_equal ["b_r1", "b_r2"], B.public_attributes.sort
assert_equal ["b2_a1"], B2.public_attributes.sort
assert_equal ["b_r1", "b_r2", "c_a1"], C.public_attributes.sort
=end