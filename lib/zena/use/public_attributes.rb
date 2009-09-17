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
            if public_attributes.include?(key.to_s)
              true
            elsif respond_to?(:nested_model_names_for_alias) && classes = nested_model_names_for_alias(key)
              # try to find sub class
              begin
                key = classes.pop
                klass = Module.const_get(classes.last.capitalize)
                klass.attr_public?(key)
              rescue NameError
                false
              end
            end
          end
        end
      end

      # Safe attribute reader used when 'safe_readable?' could not be called because the class
      # is not known during compile time.
      def public_read(key)
        return read_custom_field(key) if custom_field?(key)
        return "'#{key}' not readable" unless self.class.attr_public?(key)
        self.send(key)
      end

      def custom_field?(key)
        !methods.include?(key) && !self.class.column_names.include?(key.to_s) && @attributes.has_key?(key)
      end

      def read_custom_field(key)
        val = @attributes[key]
        if key =~ /_at$/ || key =~ /_date$/
          self.class.columns.first.class.string_to_time(val)
        elsif key =~ /_count$/
          val.to_i
        else
          val
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
  include Zena::Use::PublicAttributes
  def self.column_names
    ['col_a','col_b']
  end
  def initialize
    @attributes = {'custom' => 'custom value'}
  end
  def foo
    'foo'
  end
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
assert_equal 'custom value', B.new.public_read('custom')
assert_equal "'col_a' not readable", B.new.public_read('col_a')
assert_equal "'foo' not readable", B.new.public_read('foo')
assert_equal "'bar' not readable", B.new.public_read('bar')
=end