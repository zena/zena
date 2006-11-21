require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  include ZenaTestUnit


  def test_create_with_file
    without_files('data/test/jpg') do
      visitor(:ant)
      doc = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :file => fixture_file_upload('/files/bird.jpg', 'image/jpeg')) }
      assert_kind_of Image , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "birdy.jpg", doc.name
      v = doc.send :version
      assert ! v.new_record? , "Version is not a new record"
      assert_not_nil v.file_ref , "File_ref is set"
      file = doc.file
      assert_kind_of ImageFile , file
      assert_equal "661x600", "#{file.width}x#{file.height}"
      assert_equal "/jpg/#{doc.v_id}/birdy.jpg", file.path
      assert File.exist?("#{RAILS_ROOT}/data/test#{file.path}")
      assert_equal File.stat("#{RAILS_ROOT}/data/test#{file.path}").size, doc.filesize
    end
  end
  
  def test_resize_image
    without_files('data/test/jpg') do
      visitor(:ant)
      doc = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater), 
                                          :inherit => 1,
                                          :name=>'birdy', :file => fixture_file_upload('/files/bird.jpg', 'image/jpeg')) }
      assert_kind_of Image , doc
      file = doc.file('pv')
      assert_kind_of ImageFile , file
      assert file.new_record? , "New record"
      assert_equal "80x80", "#{file.width}x#{file.height}"
      file.save # write image to disk
      assert_equal "/jpg/#{doc.v_id}/birdy-pv.jpg", file.path
    end
  end
end
