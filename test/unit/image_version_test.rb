require 'test_helper'

class ImageVersionTest < Zena::Unit::TestCase
  
  def test_set_image_text
    without_files('data/test/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert_kind_of Image , img
      assert ! img.new_record? , "Not a new record"
      assert_equal "!#{img[:zip]}!", img.v_text
    end
  end

end
