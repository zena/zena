require 'test_helper'

class ImageTest < Zena::Unit::TestCase

  # don't use transaction fixtures so that after_commit (implemented in Versions gem) works.
  self.use_transactional_fixtures = false

  context 'On create an image' do
    setup do
      login(:tiger)
    end

    teardown do
      FileUtils.rm(subject.filepath) if subject && subject.version.attachment
    end

    subject do
      secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :name=>'birdy',
                                          :file => uploaded_jpg('bird.jpg')) }
    end

    should 'record be valid' do
      subject.valid?
    end

    should 'record be saved in database' do
      assert !subject.new_record?
    end

    should 'save image in File System' do
      assert File.exist?(subject.filepath)
    end

    should 'save original filename' do
      assert_equal 'bird.jpg', subject.file.original_filename
    end

    should 'be kind of Image' do
      assert_kind_of Image , subject
    end

    should 'save ext (extension)' do
      assert_equal 'jpg', subject.ext
    end

    should 'save content type' do
      assert_equal 'image/jpeg', subject.content_type
    end

    should 'save width with full format' do
      assert_equal 660, subject.width
    end

    should 'save height with full format' do
      assert_equal 600, subject.height
    end

    should 'create a version' do
      assert_not_nil subject.version.id
    end

    should 'create an attachment' do
      assert_not_nil subject.version.attachment.id
    end
  end

  context 'On resize image' do
    setup do
      @pv_format = Iformat['pv']
      login(:ant)
    end

    teardown do
      FileUtils.rm(subject.filepath) if subject && subject.version.attachment
    end

    subject do
      secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :name=>'birdy', :file => uploaded_jpg('bird.jpg')) }
    end

    should 'return resolution widthxheight' do
      assert_equal "70x70", "#{subject.width(@pv_format)}x#{subject.height(@pv_format)}"
    end

    should 'create a new file corresponding to the new format' do
      assert !File.exist?( subject.filepath(@pv_format) )
    end

    should 'return file corresponding to the new format' do
      assert_not_nil subject.file(@pv_format)
    end
  end

  context 'On accept content type' do

    should 'Image accept jpeg' do
      assert Image.accept_content_type?('image/jpeg')
    end

    should 'not accepect pdf' do
      assert !Image.accept_content_type?('application/pdf')
    end
  end

  context 'On update image file' do
    setup do
      login(:tiger)
      @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :title=>'birdy', :file => uploaded_jpg('bird.jpg')) }
      @img.update_attributes(:file=>uploaded_jpg('flower.jpg'))
    end

    teardown do
      FileUtils.rm(subject.filepath) if subject.version.attachment
    end

    subject do
      @img
    end

    should 'record be valid' do
      assert subject.valid?
    end

    should 'record be saved' do
      assert !subject.new_record?
    end

    should 'change file name' do
      assert_equal 'flower.jpg', subject.filename
    end

    should 'change filepath' do
      assert_match /flower.jpg/, subject.filepath
    end

    should 'change image width' do
      assert_equal 800, subject.width
    end

    should 'change image height' do
      assert_equal 800, subject.width
    end

    should 'change image size' do
      assert_equal 96648, subject.size
    end
  end

  context 'On update non image file' do
    setup do
      login(:tiger)
      @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :title=>'spring', :file => uploaded_jpg('flower.jpg')) }
      @img.update_attributes(:file=>uploaded_text('some.txt'))
    end

    teardown do
      FileUtils.rm(subject.filepath) if File.exist?(subject.filepath)
    end

    subject do
      @img
    end

    should 'not change content type' do
      assert 'image/jpeg', subject.content_type
    end

    should 'not change file name' do
      assert 'flower.jpg', subject.filename
    end

    should 'not change file path' do
      assert_match /flower.jpg/, subject.filepath
    end

    should 'not create a version' do
      assert 1, subject.versions.size
    end
  end


  def test_change_image_bad_file
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      flo = secure!(Node) { nodes(:flower_jpg)}
      assert_equal 56243, img.version.content.size
      assert_equal 'image/jpeg', img.c_content_type
      assert !img.update_attributes(:c_file=>uploaded_text('some.txt'))
      img = secure!(Node) { nodes(:bird_jpg) } # reload
      assert_equal 56243, img.version.content.size
      assert_equal 'image/jpeg', img.c_content_type
    end
  end

  def test_crop_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.content.id
      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
      assert_equal 56243, img.version.content.size
      assert img.update_attributes(:c_crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_not_equal pub_content_id, img.version.content.id
      assert_equal 2010,   img.version.content.size
      assert_equal 160,  img.version.content.width
      assert_equal 80, img.version.content.height
      up1 = img.updated_at
      # crop again, same redaction
      sleep(1)
      assert img.update_attributes(:c_crop=>{:x=>0,:y=>0,:w=>'100',:h=>50})
      img = secure!(Node) { nodes(:bird_jpg) }
      # this verifies that updated_at is updated even when we only change the content
      assert_not_equal up1, img.updated_at
      assert_equal 100,  img.version.content.width
      assert_equal 50, img.version.content.height
    end
  end

  def test_crop_image_limit
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.content.id
      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
      assert_equal 56243, img.version.content.size
      assert img.update_attributes(:c_crop=>{:max_value=>'30', :max_unit=>'Kb'})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_not_equal pub_content_id, img.version.content.id
      assert img.version.content.size < 30 * 1024 * 1.2
    end
  end

  def test_crop_iformat
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.content.id
      img.update_attributes(:c_crop=>{:format=>'png'})
      # should build a new version
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_not_equal pub_content_id, img.version.content.id
      #assert_equal 20799,   img.version.content.size
      assert_equal 'png', img.c_ext
    end
  end

  def test_crop_image_same_size
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.content.id
      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
      # crop keeping same size => do nothing => keep content
      assert !img.version.content.can_crop?('x'=>'0','y'=>0,'w'=>'660','h'=>600)
      img.update_attributes(:v_text=>"hey", :c_crop=>{:x=>'0',:y=>0,:w=>'660',:h=>600})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_equal pub_version_id, img.version.content_id
      assert_equal pub_content_id, img.version.content.id
      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
    end
  end

  def test_crop_image_with_new_file
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.content.id
      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
      assert_equal 56243, img.version.content.size
      assert img.update_attributes(:name => 'lila.jpg', :c_file=>uploaded_jpg('flower.jpg'), :c_crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal 800, img.version.content.width
      assert_equal 600, img.version.content.height
      assert_equal 96648,  img.version.content.size
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
      old_path1 = img.version.content.filepath
      pv_format = Iformat['pv']
      old_path2 = img.version.content.filepath(pv_format)
      img.c_file(pv_format) # creates 'pv' file
      assert_equal file_path("birdy.jpg", 'full', img.version.content.id), old_path1
      assert_equal file_path("birdy.jpg", 'pv', img.version.content.id), old_path2
      assert File.exists?(old_path1), "Old file exist."
      assert File.exists?(old_path2), "Old file with 'pv' format exist."
      assert img.update_attributes(:name=>'moineau')
      # image content name should not change
      assert_equal old_path1, img.version.content.filepath
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
      v1      = img.version.id
      old1    = img.version.content.filepath
      pv_format = Iformat['pv']
      old1_pv = img.version.content.filepath(pv_format)
      img.c_file(pv_format) # creates 'pv' file

      img = secure!(Image) { Image.find(img_id) }
      # create a new redaction with a new file
      assert img.update_attributes(:c_file=> uploaded_jpg('flower.jpg'))

      # publish new redaction
      assert img.publish

      v2      = img.version.id
      old2    = img.version.content.filepath
      old2_pv = img.version.content.filepath(pv_format)

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
      assert_equal 793, img.version.content.size
      assert img.c_file(Iformat['pv'])
    end
  end

  def test_update_same_image
    login(:tiger)
    bird = secure!(Node) { nodes(:bird_jpg) }
    assert_equal Digest::MD5.hexdigest(bird.c_file.read),
                 Digest::MD5.hexdigest(uploaded_jpg('bird.jpg').read)
    bird.c_file.rewind
    assert_equal 1, bird.versions.count
    assert_equal '2006-04-11 00:00', bird.updated_at.strftime('%Y-%m-%d %H:%M')
    assert !bird.version.would_edit?('content_attributes' => {'file' => uploaded_jpg('bird.jpg')})
    assert bird.update_attributes(:c_file => uploaded_jpg('bird.jpg'))
    assert_equal 1, bird.versions.count
    assert_equal '2006-04-11 00:00', bird.updated_at.strftime('%Y-%m-%d %H:%M')
    assert bird.update_attributes(:c_file => uploaded_jpg('flower.jpg'))
    assert_equal 2, bird.versions.count
    assert_not_equal '2006-04-11 00:00', bird.updated_at.strftime('%Y-%m-%d %H:%M')
  end

  def test_set_event_at_from_exif_tags
    without_files('test.host/data/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'lake',
                                          :c_file => uploaded_jpg('exif_sample.jpg')) }
      assert_equal 'SANYO Electric Co.,Ltd.', img.c_exif['Make']

      # reload
      assert img = secure!(Image) { Image.find(img.id) }
      assert exif_tags = img.c_exif
      assert_equal 'SANYO Electric Co.,Ltd.', img.c_exif['Make']
      assert_equal Time.parse("1998-01-01 00:00:00"), img.c_exif.date_time
      assert_equal Time.parse("1998-01-01 00:00:00"), img.event_at
    end
  end

end
