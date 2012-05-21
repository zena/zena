require 'test_helper'

class OrderedHashTest < Test::Unit::TestCase

  context 'An OrderedHash' do
    setup do
      @hash = Zafu::OrderedHash.new
      @hash[:a] = 1
      @hash[:c] = 2
      @hash[:b] = 3
    end

    should 'keep keys in insertion order' do
      assert_equal [:a, :c, :b], @hash.keys
    end

    should 'list each in insertion order' do
      res = []
      @hash.each do |k, v|
        res << v
      end
      assert_equal [1, 2, 3], res
    end

    should 'remove entry on delete' do
      @hash.delete(:c)
      assert_equal [:a, :b], @hash.keys
    end
    
    context 'running through keys' do
      should 'allow key alteration' do
        @hash.keys.each do |k|
          assert k != :d
          @hash[:d] = 'x'
        end
      end
    end
    
    context 'running each' do
      should 'allow key alteration' do
        @hash.each do |k, v|
          assert k != :d
          @hash[:d] = 'x'
        end
      end
    end

    context 'with a duplicate' do
      setup do
        @dup = @hash.dup
      end

      should 'not alter duplicate on set' do
        @hash[:d] = 4
        assert_equal [:a, :c, :b], @dup.keys
      end

      should 'not alter duplicate on change' do
        @hash[:a] = 10
        assert_equal 1, @dup[:a]
      end

      should 'not alter duplicate on delete' do
        @hash.delete(:a)
        assert_equal [:a, :c, :b], @dup.keys
      end
    end
  end
end