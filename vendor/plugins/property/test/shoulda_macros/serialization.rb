class Test::Unit::TestCase

  def self.should_encode_and_decode_properties
    klass = self.name.gsub(/Test$/,'').constantize
    context klass do
      should 'respond to validate_property_class' do
        assert klass.respond_to? :validate_property_class
      end

      [Property::Properties, String, Integer, Float].each do |a_class|
        should "accept to serialize #{a_class}" do
          assert klass.validate_property_class(a_class)
        end
      end
    end

    context "Instance of #{klass}" do
      setup do
        @obj = klass.new
      end

      should 'respond to :encode_properties' do
        assert @obj.respond_to? :encode_properties
      end

      should 'respond to :decode_properties' do
        assert @obj.respond_to? :decode_properties
      end

      context 'with Properties' do
        setup do
          @properties = Property::Properties[:foo=>:bar]
        end

        should 'encode Properties in string' do
          assert_kind_of String, @obj.encode_properties(@properties)
        end

        should 'restore Properties from string' do
          string = @obj.encode_properties(@properties)
          properties = @obj.decode_properties(string)
          assert_equal Property::Properties, properties.class
          assert_equal @properties, properties
        end

        should 'not include instance variables' do
          @properties.instance_eval do
            @baz   = 'some data'
            @owner = Version.new
          end
          @obj.decode_properties(encode_properties(@properties)).instance_eval do
            assert_nil @baz
            assert_nil @owner
          end
        end
      end

      context 'with empty Properties' do
        setup do
          @properties = Property::Properties.new
        end

        should 'encode and decode' do
          string = @obj.encode_properties(@properties)
          properties = @obj.decode_properties(string)
          assert_equal Property::Properties, properties.class
          assert_equal @properties, properties
        end
      end
    end
  end
end