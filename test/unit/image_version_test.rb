require File.dirname(__FILE__) + '/../test_helper'

class ImageVersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Image) { Image.find( items_id(:bird_jpg) ) }
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag('pv')
  end
end
