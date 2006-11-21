require File.dirname(__FILE__) + '/../test_helper'

class ImageVersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_file
    preserving_files('data/test/jpg') do
      visitor(:tiger)
      doc = secure(Image) { Image.find( items_id(:bird_jpg) ) }
      version = doc.send(:version)
      assert_equal 20, version[:id]
      file = version.file
      assert_equal 661, file.width
      assert_equal 0, ImageFile.find_all_by_version_id_and_format(20,'pv').size
      file = version.file('pv')
      assert_equal 1, ImageFile.find_all_by_version_id_and_format(20,'pv').size
    end
  end
  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Image) { Image.find( items_id(:bird_jpg) ) }
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag
    assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_nothing_raised { doc.file('pv').read }
  end
end
