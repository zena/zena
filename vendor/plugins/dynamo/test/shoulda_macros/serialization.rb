class Test::Unit::TestCase

  def self.should_serialization_encode
    klass = self.name.gsub(/Test$/,'').constantize
    context "Instance of #{klass}" do
      setup do
        @obj = klass.new
      end
      should "respond to :encode" do
        assert @obj.respond_to? :encode
      end
      should "encode Hash in string" do
        assert_kind_of String, @obj.encode({:foo=>:bar})
      end
      should "encode Array in sring" do
        assert @obj.encode([:foo, :bar])
      end
    end
  end


  def self.should_serialization_decode
    klass = self.name.gsub(/Test$/,'').constantize
    context "Instance of #{klass}" do
      setup do
        @obj = klass.new
        @hash = {:foo=>:bar}
      end
      should "respond to :decode" do
        assert @obj.respond_to? :decode
      end
      should "decode return initial data" do
        encoding = @obj.encode(@hash)
        assert_equal @hash, @obj.decode(encoding)
      end
    end
  end
end