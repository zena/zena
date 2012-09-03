module Zafu

  if RUBY_VERSION.split('.')[0..1].join('.').to_f > 1.8
    OrderedHash = Hash
  elsif !defined?(OrderedHash)
    class OrderedHash < Hash

      def []=(k, v)
        get_keys << k unless get_keys.include?(k)
        super
      end

      def merge!(hash)
        hash.keys.each do |k|
          get_keys << k unless get_keys.include?(k)
        end
        super
      end

      def merge(hash)
        res = dup
        res.merge!(hash)
        res
      end
      
      alias o_keys keys
      
      def get_keys
        @keys ||= o_keys
      end

      def keys
        get_keys.dup
      end

      def each
        keys.each do |k|
          yield(k, self[k])
        end
      end

      def delete(k)
        get_keys.delete(k)
        super
      end

      def dup
        copy = super
        copy.instance_variable_set(:@keys, keys)
        copy
      end
    end
  end
end