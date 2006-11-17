require File.dirname(__FILE__) + '/../test_helper'

class ImageFileTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_self_find_or_new
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en))
    assert_equal 1, imf.id
    assert !imf.new_record?, "Not a new record"
    assert_equal 661, imf.width
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en),'pv')
    assert imf.new_record?, "New record"
    assert_equal 80, imf.width
  end
    
  def test_self_find_or_new_no_fileinfo
    ImageFile.connection.execute "DELETE FROM doc_files WHERE version_id=#{versions_id(:bird_jpg_en)}"
    assert_raise(ActiveRecord::RecordNotFound) { ImageFile.find_or_new(versions_id(:bird_jpg_en)) }
  end
  
  if Magick.const_defined?(:ZenaDummy)
    def test_set_file
      preserving_files('/data/test/jpg') do
        imf = ImageFile.new(:version_id => versions_id(:bird_jpg_en))
        imf.file = uploaded_jpg('bird.jpg')
        assert_nil imf.width
        assert_nil imf.height
        assert imf.save, "Can save"
      end
    end
    
    def test_dummy
      imf = ImageFile.new
      assert imf.dummy?, "Is a dummy"
    end
  else
    def test_set_file
      preserving_files('/data/test/jpg') do
        imf = ImageFile.new(:version_id => versions_id(:bird_jpg_en))
        imf.file = uploaded_jpg('bird.jpg')
        assert_equal 661, imf.width
        assert_equal 600, imf.height
        assert imf.save, "Can save"
      end
    end
    
    def test_dummy
      imf = ImageFile.new
      assert !imf.dummy?, "Not a dummy"
    end
  end
  
  def test_read
    
  end
  
  def test_read_new
    
  end
  
  def test_read_no_file
    
  end
  
end
