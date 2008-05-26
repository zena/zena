require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < ZenaTestUnit

  def test_create_with_file
    without_files('test.host/data/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert_kind_of Image , img
      assert ! img.new_record? , "Not a new record"
      assert_equal "birdy", img.name
      assert ! img.v_new_record? , "Version is not a new record"
      assert_nil img.v_content_id , "content_id is nil"
      assert_kind_of ImageVersion , img.version
      assert_equal 'jpg', img.c_ext
      assert_equal "660x600", "#{img.c_width}x#{img.c_height}"
      assert_equal file_path("birdy.jpg", 'full', img.c_id), img.c_filepath
      assert File.exist?(img.c_filepath)
      assert_equal File.stat(img.c_filepath).size, img.c_size
    end
  end
  
  def test_resize_image
    pv_format = Iformat['pv']
    without_files('test.host/data/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater), 
                                          :inherit => 1,
                                          :name=>'birdy', :c_file => uploaded_jpg('bird.jpg')) }
      assert !img.new_record?, "Not a new record"
      assert  File.exist?( img.c_filepath       ), "File exist"
      assert_equal "70x70", "#{img.c_width(pv_format)}x#{img.c_height(pv_format)}"
      assert !File.exist?( img.c_filepath(pv_format) ), "File does not exist"
      assert  img.c_file(pv_format), "Can make 'pv' image"
      assert  File.exist?( img.c_filepath(pv_format) ), "File exist"
      assert_equal file_path('birdy.jpg', 'pv', img.c_id), img.c_filepath(pv_format)
    end
  end
  
  def test_image_content_type
    assert Image.accept_content_type?('image/jpeg')
    assert !Image.accept_content_type?('application/pdf')
  end
  
  def test_change_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      flo = secure!(Node) { nodes(:flower_jpg)}
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
      assert_equal 56243, img.c_size
      assert_equal 800, flo.c_width
      assert_equal 600, flo.c_height
      assert_equal 96648,  flo.c_size
      assert img.update_attributes(:c_file=>uploaded_jpg('flower.jpg'))
      assert_equal flo.c_size,   img.c_size
      assert_equal flo.c_width,  img.c_width
      assert_equal flo.c_height, img.c_height
      # make sure old formated images are destroyed
    end
  end
  
  def test_change_image_bad_file
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      flo = secure!(Node) { nodes(:flower_jpg)}
      assert_equal 56243, img.c_size
      assert_equal 'image/jpeg', img.c_content_type
      assert !img.update_attributes(:c_file=>uploaded_text('some.txt'))
      img = secure!(Node) { nodes(:bird_jpg) } # reload
      assert_equal 56243, img.c_size
      assert_equal 'image/jpeg', img.c_content_type
    end
  end
  
  def test_crop_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.v_status
      pub_version_id = img.v_id
      pub_content_id = img.c_id
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
      assert_equal 56243, img.c_size
      assert img.update_attributes(:c_crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.v_id
      assert_not_equal pub_content_id, img.c_id
      assert_equal 2010,   img.c_size
      assert_equal 160,  img.c_width
      assert_equal 80, img.c_height
    end
  end
  
  def test_crop_image_limit
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.v_status
      pub_version_id = img.v_id
      pub_content_id = img.c_id
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
      assert_equal 56243, img.c_size
      assert img.update_attributes(:c_crop=>{:max_value=>'30', :max_unit=>'Kb'})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.v_id
      assert_not_equal pub_content_id, img.c_id
      assert img.c_size < 30 * 1024 * 1.2
    end
  end
  
  def test_crop_iformat
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.v_status
      pub_version_id = img.v_id
      pub_content_id = img.c_id
      assert img.update_attributes(:c_crop=>{:format=>'png'})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.v_id
      assert_not_equal pub_content_id, img.c_id
      #assert_equal 20799,   img.c_size
      assert_equal 'png', img.c_ext
    end
  end
  
  def test_crop_image_same_size
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.v_status
      pub_version_id = img.v_id
      pub_content_id = img.c_id
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
      # crop keeping same size = do nothing
      assert img.update_attributes(:v_text=>"hey", :c_crop=>{:x=>'0',:y=>0,:w=>'660',:h=>600})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.v_id
      assert_equal pub_version_id, img.version.content_id
      assert_equal pub_content_id, img.version.content.id
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
    end
  end
  
  def test_crop_image_with_new_file
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.v_status
      pub_version_id = img.v_id
      pub_content_id = img.c_id
      assert_equal 660, img.c_width
      assert_equal 600, img.c_height
      assert_equal 56243, img.c_size
      assert img.update_attributes(:name => 'lila.jpg', :c_file=>uploaded_jpg('flower.jpg'), :c_crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal 800, img.c_width
      assert_equal 600, img.c_height
      assert_equal 96648,  img.c_size
    end
  end
  
  def test_change_name
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert !img.new_record?
      img = secure!(Image) { Image.find(img[:id]) }
      old_path1 = img.c_filepath
      pv_format = Iformat['pv']
      old_path2 = img.c_filepath(pv_format)
      img.c_file(pv_format) # creates 'pv' file
      assert_equal file_path("birdy.jpg", 'full', img.c_id), old_path1
      assert_equal file_path("birdy.jpg", 'pv', img.c_id), old_path2
      assert File.exists?(old_path1), "Old file exist."
      assert File.exists?(old_path2), "Old file with 'pv' format exist."
      assert img.update_attributes(:name=>'moineau')
      # image content name should not change
      assert_equal old_path1, img.c_filepath
      assert File.exists?(old_path1), "Old file exist."
      assert File.exists?(old_path2), "Old file with 'pv' format exist."
    end
  end
  
  def test_change_name_many_versions
    preserving_files('test.host/data') do
      login(:lion)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy', 
                                          :c_file => uploaded_jpg('bird.jpg')) }

                                          err img
      assert !img.new_record?
      
      img = secure!(Image) { Image.find(img[:id]) }
      assert img.publish
      img_id  = img[:id]
      v1      = img.v_id
      old1    = img.c_filepath
      pv_format = Iformat['pv']
      old1_pv = img.c_filepath(pv_format)
      img.c_file(pv_format) # creates 'pv' file
      
      img = secure!(Image) { Image.find(img_id) }
      # create a new redaction with a new file
      assert img.update_attributes(:c_file=> uploaded_jpg('flower.jpg'))
      
      # publish new redaction
      assert img.publish
      
      v2      = img.v_id
      old2    = img.c_filepath
      old2_pv = img.c_filepath(pv_format)
      
      img.c_file(pv_format) # creates 'pv' file
      
      [old1,old1_pv,old2,old2_pv].each do |path|
        assert File.exists?(path), "Path #{path.inspect} should exist"
      end
      
      # We do not propagate 'name' change to document_content 'name' because this is only used to find document content and
      # retrieve data in case the whole database goes havoc.
      assert img.update_attributes(:name=>'moineau')
      
      [old1,old1_pv,old2,old2_pv].each do |path|
        assert File.exists?(path), "Path #{path.inspect} did not change"
      end
      
      version1 = Version.find(v1)
      version2 = Version.find(v2)
      new1 = version1.content.filepath
      new2 = version2.content.filepath
      assert File.exists?(new1), "New file exists"
      assert File.exists?(new2), "New file exists"
    end
  end
  
  def test_create_with_small_file
    preserving_files('/sites/test.host/data') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
        :name => 'bomb.png',
        :c_file => uploaded_png('bomb.png') )}
      assert_kind_of Image, img
      assert ! img.new_record?, "Not a new record"
      assert_equal 793, img.c_size
      assert img.c_file(Iformat['pv'])
    end
  end
end
