require File.dirname(__FILE__) + '/../test_helper'

class ImageBuilderTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  # Dummy tests
  if Magick.const_defined?(:ZenaDummy)
    def test_dummy
      img = nil
      assert_nothing_raised { img = ImageBuilder.new(:width=>100, :height=>30) }
      assert_nil img.read
    end
  else
  end

  
  def test_resize
    img = ImageBuilder.new(:width=>611,:height=>800)
    assert_equal 611, img.width
    assert_equal 800, img.height
    crop_scale = [600.0/611, 400.0/800].min
    assert_equal 0.5, crop_scale
    img.resize!(crop_scale)
    assert_equal 305.5, img.width
    assert_equal 400, img.height
    img.crop_min!(600, 400)
    assert_equal 305.5, img.width
    assert_equal 400, img.height
  end
end
