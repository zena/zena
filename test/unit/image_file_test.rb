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
      imf = ImageFile.new(:version_id => versions_id(:bird_jpg_en), :ext=>'jpg')
      assert !imf.dummy?, "Is not a dummy"
    end
  end
  
  def test_self_find_or_create
    preserving_files('/data/test/jpg/20') do
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      assert_equal 1, imf.id
      assert !imf.new_record?, "Not a new record"
      assert_equal 661, imf.width
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird.jpg"), "File exists"
      assert !File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File does not exist"
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en),'pv')
      assert !imf.new_record?, "Not a new record"
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File exists"
      assert_equal 80, imf.width
    end
  end
    
  def test_self_find_or_create_no_fileinfo
    ImageFile.connection.execute "DELETE FROM document_contents WHERE version_id=#{versions_id(:bird_jpg_en)}"
    assert_raise(ActiveRecord::RecordNotFound) { ImageFile.find_or_create(versions_id(:bird_jpg_en)) }
  end
  
  def test_img_tag
    preserving_files('/data/test/jpg/20') do
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600' class='full'/>", imf.img_tag
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='80' height='80' class='pv'/>", imf.img_tag
    end
  end
  
  def test_transform
    imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
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
    ImageFile.connection.execute "UPDATE document_contents SET size=NULL WHERE id=#{document_contents_id(:bird_jpg)}"
    without_files('/data/test/jpg') do
      imf = ImageFile.find(document_contents_id(:bird_jpg))
      assert_nil imf[:size]
      assert_nil imf.size
    end
    imf = ImageFile.find(document_contents_id(:bird_jpg))
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
  
  def test_save_file
    preserving_files('data/test/jpg/20') do
      Version.connection.execute "UPDATE versions SET status=20 WHERE id=#{versions_id(:bird_jpg_en)}"
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      assert File.exist?(imf.send(:filepath)), "File exists"
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      assert !imf.new_record?, "Not a new record"
      assert File.exist?(imf.send(:filepath)), "File exist"
    end
  end
  
  def test_change_file
    preserving_files('data/test/jpg/20') do
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      imf2 = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'mini')
      imf3 = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      imfcount = ImageFile.find(:all).size
      assert !imf2.new_record?, "Not a new record"
      assert File.exist?(imf2.send(:filepath)), "File exists"
      assert File.exist?(imf3.send(:filepath)), "File exists"
      assert_equal 56183, imf.size
      
      imf.file = uploaded_jpg('flower.jpg')
      assert imf.save, "Can save"
      assert !File.exist?(imf2.send(:filepath)), "File does not exist"
      assert !File.exist?(imf3.send(:filepath)), "File does not exist"
      assert_equal imfcount-2, ImageFile.find(:all).size
      assert_equal 96574, imf.size
    end
  end
  
  def test_read_save_file
    preserving_files('data/test/jpg/20') do
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      assert File.exist?(imf.send(:filepath)), "File exists"
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      assert !imf.new_record?, "Not a new record"
      assert_equal 80, imf[:width]
      assert_equal 80, imf[:height]
      imf[:width] = 40
      imf.save
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      assert_equal 40, imf[:width]
      FileUtils::rm("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg")
      assert !File.exist?(imf.send(:filepath)), "File does not exist"
      assert imf.read
      assert File.exist?(imf.send(:filepath)), "File exist"
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'pv')
      assert_equal 80, imf[:width] # width has been saved
      assert_equal 2643, imf[:size] # size saved too
    end
  end
  
  def test_filename
    preserving_files('data/test/jpg/20') do
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en))
      assert_equal 'bird.jpg', imf.filename
      imf = ImageFile.find_or_create(versions_id(:bird_jpg_en), 'med')
      assert_equal 'bird-med.jpg', imf.filename
    end
  end
  
  def test_clone
    imf = ImageFile.new
    file = uploaded_pdf('bird.jpg')
    imf.file = file
    other = imf.clone
    assert_equal file.object_id, other.instance_eval{@file}.object_id
  end
end
