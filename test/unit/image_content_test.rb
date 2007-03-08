require File.dirname(__FILE__) + '/../test_helper'

class ImageContentTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  if Magick.const_defined?(:ZenaDummy)
    def test_set_file
      preserving_files('/data/test/jpg/20') do
        img = ImageContent.new(:version_id => versions_id(:bird_jpg_en))
        img.file = uploaded_jpg('bird.jpg')
        assert_nil img.width
        assert_nil img.height
        assert img.save, "Can save"
      end
    end
  else
    def test_set_file
      preserving_files('/data/test/jpg/20') do
        img = ImageContent.new(:version_id => versions_id(:bird_jpg_en))
        img.file = uploaded_jpg('bird.jpg')
        assert_equal 661, img.width
        assert_equal 600, img.height
        assert img.save, "Can save"
      end
    end
  end
  
  def test_formats
    preserving_files('/data/test/jpg/20') do
      img = document_contents(:bird_jpg)
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird.jpg"), "File exists"
      assert !File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File does not exist"
      assert_equal 661, img.width
      assert_equal 70,  img.width('pv')
      assert !File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File does not exist"
      assert_equal 2249, img.size('pv')
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"), "File exist"
    end
  end
  
  def test_file_formats
    preserving_files('/data/test/jpg/20') do
      img = document_contents(:bird_jpg)
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird.jpg"     ), "File exists"
      assert !File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg" ), "File does not exist"
      assert !File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-med.jpg"), "File does not exist"
      assert img.file
      assert img.file('pv')
      assert img.file('med')
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-pv.jpg"  ), "File exist"
      assert File.exist?("#{RAILS_ROOT}/data/test/jpg/20/bird-med.jpg" ), "File exist"
    end
  end
  
  def test_img_tag
    preserving_files('/data/test/jpg/20') do
      img = document_contents(:bird_jpg)
      assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600' alt='bird' class='full'/>", img.img_tag
      assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='70' height='70' alt='bird' class='pv'/>", img.img_tag('pv')
    end
  end
  
  def test_img_tag_opts
    preserving_files('/data/test/jpg/20') do
      img = document_contents(:bird_jpg)
      assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600' alt='bird' id='yo' class='full'/>", img.img_tag(nil, :id=>'yo')
      assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='70' height='70' alt='bird' id='yo' class='super'/>", img.img_tag('pv', :id=>'yo', :class=>'super')
      assert_equal "<img src='/data/jpg/20/bird-pv.jpg' width='70' height='70' alt='super man' class='pv'/>", img.img_tag('pv', :alt=>'super man')
    end
  end
  
  def test_remove_formatted_on_file_change
    preserving_files('data/test/jpg/20') do
      img  = document_contents(:bird_jpg)
      assert img.file('pv')  # create image with 'pv'  format
      assert img.file('med') # create image with 'med' format
      # we have 3 files now
      assert File.exist?(img.filepath       ), "File exist"
      assert File.exist?(img.filepath('pv') ), "File exist"
      assert File.exist?(img.filepath('med')), "File exist"
      # change file
      img.file = uploaded_jpg('flower.jpg')
      assert img.save, "Can save"
      assert File.exist?(img.filepath       ), "File exist"
      assert !File.exist?(img.filepath('pv') ), "File does not exist"
      assert !File.exist?(img.filepath('med')), "File does not exist"
      # change name
      old_path = img.filepath
      img.file('med') # create image with 'med' format
      med_path  = img.filepath('med')
      assert File.exist?(  med_path          ), "File exist"
      img.version.node.name = 'new'
      assert img.save, "Can save"
      assert !File.exist?(  old_path         ), "File does not exist"
      assert !File.exist?(  med_path         ), "File does not exist"
      assert File.exist?(   img.filepath     ), "File exist"
    end
  end
  
  def test_remove_image
    preserving_files('data/test/jpg/20') do
      img  = document_contents(:bird_jpg)
      assert img.file('pv')  # create image with 'pv'  format
      assert img.file('med') # create image with 'med' format
      # we have 3 files now
      assert File.exist?(img.filepath       ), "File exist"
      assert File.exist?(img.filepath('pv') ), "File exist"
      assert File.exist?(img.filepath('med')), "File exist"
      # remove file
      assert img.remove_image('pv')
      assert File.exist?(img.filepath       ), "File exist"
      assert !File.exist?(img.filepath('pv') ), "File does not exist"
      assert File.exist?(img.filepath('med')), "File exist"
      
      
      assert img.remove_image('med')
      assert File.exist?(img.filepath       ), "File exist"
      assert !File.exist?(img.filepath('med') ), "File does not exist"
      
      assert !img.remove_image(  nil ), "Cannot remove original file"
      assert !img.remove_image('full'), "Cannot remove original file"
    end
  end
  
  def test_verify_format
    preserving_files('data/test/jpg/20') do
      img  = document_contents(:bird_jpg)
      assert_equal "#{RAILS_ROOT}/data/test/jpg/20/bird-std.jpg", img.filepath('../../')
      assert !File.exist?(img.filepath('std') ), "File does not exist"
      assert img.file('../../')
      assert File.exist?(img.filepath('std') ), "File exist"
    end
  end
  
end
