require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  include ZenaTestUnit

  def test_create_with_file
    without_files('data/test/jpg') do
      visitor(:ant)
      img = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert_kind_of Image , img
      assert ! img.new_record? , "Not a new record"
      assert_equal "birdy", img.name
      assert ! img.v_new_record? , "Version is not a new record"
      assert_nil img.v_content_id , "content_id is nil"
      assert_kind_of ImageVersion , img.send(:version)
      assert_equal 'jpg', img.c_ext
      assert_equal "661x600", "#{img.c_width}x#{img.c_height}"
      assert_equal "/jpg/#{img.v_id}/birdy.jpg", img.c_path
      assert File.exist?("#{RAILS_ROOT}/data/test#{img.c_path}")
      assert_equal File.stat("#{RAILS_ROOT}/data/test#{img.c_path}").size, img.c_size
    end
  end
  
  def test_resize_image
    without_files('data/test/jpg') do
      visitor(:ant)
      img = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater), 
                                          :inherit => 1,
                                          :name=>'birdy', :c_file => uploaded_jpg('bird.jpg')) }
      assert !img.new_record?, "Not a new record"
      assert  File.exist?( img.c_filepath       ), "File exist"
      assert_equal "80x80", "#{img.c_width('pv')}x#{img.c_height('pv')}"
      assert !File.exist?( img.c_filepath('pv') ), "File does not exist"
      assert  img.c_file('pv'), "Can make 'pv' image"
      assert  File.exist?( img.c_filepath('pv') ), "File exist"
      assert_equal "#{RAILS_ROOT}/data/test/jpg/#{img.v_id}/birdy-pv.jpg", img.c_filepath('pv')
    end
  end
  
  def test_image_content_type
    assert Image.image_content_type?('image/jpeg')
    assert !Image.image_content_type?('application/pdf')
  end
  
  def test_change_image
    preserving_files('data/test/jpg') do
      visitor(:ant)
      img = secure(Item) { items(:bird_jpg) }
      flo = secure(Item) { items(:flower_jpg)}
      assert_equal 661, img.c_width
      assert_equal 600, img.c_height
      assert_equal 56183, img.c_size
      assert_equal 800, flo.c_width
      assert_equal 600, flo.c_height
      assert_equal 96648,  flo.c_size
      assert img.update_attributes(:c_file=>uploaded_jpg('flower.jpg'))
      assert_equal flo.c_size,   img.c_size
      assert_equal flo.c_width,  img.c_width
      assert_equal flo.c_height, img.c_height
    end
  end
  
  def test_change_name
    preserving_files('data/test/jpg') do
      visitor(:ant)
      img = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert !img.new_record?
      img = secure(Image) { Image.find(img[:id]) }
      old_path1 = img.c_filepath
      old_path2 = img.c_filepath('pv')
      img.c_file('pv') # creates 'pv' file
      assert_equal "#{RAILS_ROOT}/data/test/jpg/#{img.v_id}/birdy.jpg", old_path1
      assert_equal "#{RAILS_ROOT}/data/test/jpg/#{img.v_id}/birdy-pv.jpg", old_path2
      assert File.exists?(old_path1), "Old file exist."
      assert File.exists?(old_path2), "Old file with 'pv' format exist."
      assert img.update_attributes(:name=>'moineau')
      assert_equal "#{RAILS_ROOT}/data/test/jpg/#{img.v_id}/moineau.jpg", img.c_filepath
      assert File.exist?(img.c_filepath), "New file exists."
      assert !File.exists?(old_path1), "Old file does not exist."
      assert !File.exists?(old_path2), "Old file with 'pv' format does not exist."
    end
  end
  
  def test_change_name_many_versions
    preserving_files('data/test/jpg') do
      visitor(:ant)
      img = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert !img.new_record?
      img = secure(Image) { Image.find(img[:id]) }
      assert img.publish
      img_id = img[:id]
      v1      = img.v_id
      old1    = img.c_filepath
      old1_pv = img.c_filepath('pv')
      img.c_file('pv') # creates 'pv' file
      img = secure(Image) { Image.find(img_id) }
      assert img.update_attributes(:c_file=> uploaded_jpg('flower.jpg'))
      img = secure(Image) { Image.find(img_id) }
       img.publish
       puts img[:id]
       err img
      v2      = img.v_id
      old2    = img.c_filepath
      old2_pv = img.c_filepath('pv')
      img.c_file('pv') # creates 'pv' file
      [old1,old1_pv,old2,old2_pv].each do |path|
        assert File.exists?(path)
      end
       img.update_attributes(:name=>'moineau')
       err img
      [old1,old1_pv,old2,old2_pv].each do |path|
        assert !File.exists?(path)
      end
      version1 = Version.find(v1)
      version2 = Version.find(v2)
      new1 = version1.content.filepath
      new2 = version2.content.filepath
      assert File.exists(new1), "New file exists"
      assert File.exists(new2), "New file exists"
    end
  end
end
