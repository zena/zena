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
end
