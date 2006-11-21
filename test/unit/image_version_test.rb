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
      assert ! File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File format does not exist"
      file = version.file('pv')
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "New file format saved"
      assert_equal 80, file.width
    end
  end
  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Image) { Image.find( items_id(:bird_jpg) ) }
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag('pv')
  end
end
