require File.dirname(__FILE__) + '/../test_helper'

class ImageFileTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  if Magick.const_defined?(:ZenaDummy)
    def test_set_file
      preserving_files('/data/test/jpg/20') do
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
      assert false, 'complete test'
    end
  else
    def test_set_file
      preserving_files('/data/test/jpg/20') do
        imf = ImageFile.new(:version_id => versions_id(:bird_jpg_en))
        imf.file = uploaded_jpg('bird.jpg')
        assert_equal 661, imf.width
        assert_equal 600, imf.height
        assert imf.save, "Can save"
      end
    end
    
    def test_dummy
      imf = ImageFile.new
      assert imf.dummy?, "Is a dummy"
      imf = ImageFile.new(:version_id => versions_id(:bird_jpg_en))
      assert !imf.dummy?, "Is not a dummy"
    end
  end
  
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
  
  def test_img_tag
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en))
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", imf.img_tag
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en), 'pv')
    assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='80' height='80' class='pv'/>", imf.img_tag
  end
  
  def test_transform
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en))
    other = imf.transform('pv')
    assert_equal '/jpg/20/bird.jpg', imf[:path]
    assert_equal '/jpg/20/bird-pv.jpg', other[:path]
    assert_equal 56183, imf.size
    assert_equal 80, other.width
    assert_equal 80, other.height
    assert_nil other[:size]
    assert_equal 2643, other.size
  end
  
  def test_size
    ImageFile.connection.execute "UPDATE doc_files SET size=NULL WHERE id=#{doc_files_id(:bird_jpg)}"
    without_files('/data/test/jpg') do
      imf = ImageFile.find(doc_files_id(:bird_jpg))
      assert_nil imf[:size]
      assert_nil imf.size
    end
    imf = ImageFile.find(doc_files_id(:bird_jpg))
    assert_nil imf[:size]
    assert_equal 56183, imf.size
    assert_equal 56183, imf[:size]
    imf = ImageFile.new
    imf.file = uploaded_pdf('bird.jpg')
    assert_equal 56183, imf.size
    assert (imf = imf.transform('pv')), 'Can transform'
    assert_nil imf[:size]
    assert_equal 2643, imf.size
  end
  
  def test_read
    preserving_files('data/test/jpg/20') do
      Version.connection.execute "UPDATE versions SET status=20 WHERE id=#{versions_id(:bird_jpg_en)}"
      imf = ImageFile.find_or_new(versions_id(:bird_jpg_en))
      assert File.exist?(imf.send(:filepath)), "File exists"
      imf = ImageFile.find_or_new(versions_id(:bird_jpg_en), 'pv')
      assert !File.exist?(imf.send(:filepath)), "File does not exist"
      assert imf.save, "Can save"
      assert !File.exist?(imf.send(:filepath)), "File does not exist"
      
      imf = ImageFile.find(imf[:id])
      assert_equal 20, imf.send(:version).status
      assert imf.read
      assert !File.exist?(imf.send(:filepath)), "File does not exist"
      
      Version.connection.execute "UPDATE versions SET status=50 WHERE id=#{versions_id(:bird_jpg_en)}"
      imf = ImageFile.find(imf[:id])
      assert_equal 50, imf.send(:version).status
      assert imf.read
      assert File.exist?(imf.send(:filepath)), "File exist"
    end
  end
  
  def test_save_image_file
  end
  
  def test_filename
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en))
    assert_equal 'bird.jpg', imf.filename
    imf = ImageFile.find_or_new(versions_id(:bird_jpg_en), 'med')
    assert_equal 'bird-med.jpg', imf.filename
  end
  
  def test_clone
    imf = ImageFile.new
    file = uploaded_pdf('bird.jpg')
    imf.file = file
    other = imf.clone
    assert_equal file.object_id, other.instance_eval{@data.file}.object_id
  end
end
