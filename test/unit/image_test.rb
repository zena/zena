require 'test_helper'

class ImageTest < Zena::Unit::TestCase

  # don't use transaction fixtures so that after_commit (implemented in Versions gem) works.
  # FIXME: remove and move dependent tests to attachment_test
  self.use_transactional_fixtures = false

  context 'Creating an image' do
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
      # FIXME: move to attachment test
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

    should 'build filepath with file name' do
      assert_match /bird.jpg/, subject.filepath
    end

    context 'with specific title' do
      setup do
        subject do
          secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                              :title=>'eagle',
                                              :file => uploaded_jpg('bird.jpg')) }
        end
      end

      should 'build filepath with file name' do
        assert_match /bird.jpg/, subject.filepath
      end
    end

  end

  context 'Resizing an image with a new format' do
    setup do
      @pv_format = Iformat['pv']
      login(:ant)
      @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :name=>'birdy', :file => uploaded_jpg('bird.jpg')) }
      @img.file(@pv_format)
    end

    teardown do
      FileUtils.rm(subject.filepath) if subject && subject.version.attachment
    end

    subject do
      @img
    end

    should 'return the resolution corresponding to the new format' do
      assert_equal "70x70", "#{subject.width(@pv_format)}x#{subject.height(@pv_format)}"
    end

    should 'return the full resolution by default' do
      assert_equal "660x600", "#{subject.width()}x#{subject.height()}"
    end

    should 'create a new file corresponding to the new format' do
      assert File.exist?( subject.filepath(@pv_format) )
    end

    should 'create a new file path witch a folder named of the format' do
      assert_match /pv/, subject.filepath(@pv_format)
    end

    should 'return file corresponding to the new format' do
      assert_kind_of File, subject.file(@pv_format)
    end

    should 'return the original path by default' do
      assert_match /full/, subject.filepath
    end

    should 'not create a version' do
      assert_equal 1, subject.versions.count
    end

    context 'and updating name' do
      setup do
        @img.update_attributes(:title=>'milan')
      end

      should 'change node name' do
        assert_equal 'milan', subject.name
      end

      should 'return the original path by default' do
        assert_match /full/, subject.filepath
      end
    end

  end

  context 'Accepting content type' do

    should 'Image accept jpeg' do
      assert Image.accept_content_type?('image/jpeg')
    end

    should 'not accepect pdf' do
      assert !Image.accept_content_type?('application/pdf')
    end
  end

  context 'Updating' do
    setup do
      login(:tiger)
      @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :title=>'birdy', :file => uploaded_jpg('bird.jpg')) }
    end

    teardown do
      FileUtils.rm(subject.filepath) if subject.version.attachment
    end

    subject do
      @img
    end

    context 'image file' do
      setup do
        @img.update_attributes(:file=>uploaded_jpg('flower.jpg'))
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
    end # image file

    context 'non image file' do
      setup do
        @img.update_attributes(:file=>uploaded_text('some.txt'))
      end

      should 'not change content type' do
        assert 'image/jpeg', subject.content_type
      end

      should 'not change file name' do
        assert 'flower.jpg', subject.filename
      end

      should 'not change file path' do
        assert_match /bird.jpg/, subject.filepath
      end

      should 'not create a version' do
        assert 1, subject.versions.size
      end
    end
  end

  context 'Croping image' do
    setup do
      login(:tiger)
      @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :title=>'goeland', :file => uploaded_jpg('bird.jpg')) }
    end

    teardown do
      FileUtils.rm(subject.filepath) if File.exist?(subject.filepath)
    end

    subject{ @img }

    should 'build filepath with file name' do
      assert_match /bird.jpg/, subject.filepath
    end

    context 'with x, y, w, h' do
      setup do
        @img.update_attributes(:crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      end

      should 'keep image valid' do
        assert subject.valid?
      end

      should 'return new size' do
        assert_equal 2010, subject.size
      end

      should 'return new width' do
        assert_equal 160, subject.width
      end

      should 'return new height' do
        assert_equal 80, subject.height
      end

      should 'keep filepath with file name' do
        assert_match /bird.jpg/, subject.filepath
      end
    end

    context 'with limitation' do
      setup do
        @img.update_attributes(:crop=>{:max_value=>'30', :max_unit=>'Kb'})
      end

      should 'keep image valid' do
        err subject
        assert subject.valid?
      end

      should 'keep size under limitation' do
        assert subject.size < 30 * 1024 * 1.2
      end

      should 'keep filepath with file name' do
        assert_match /bird.jpg/, subject.filepath
      end
    end

    context 'with iformat' do
      setup do
        @img.update_attributes(:crop=>{:format=>'png'})
      end

      should 'keep image valid' do
        err subject
        assert subject.valid?
      end

      should 'change image extension' do
        assert_equal 'png', subject.ext
      end

      should 'change content_type' do
        assert_equal 'image/png', subject.content_type
      end
    end

    context 'with same size' do
      setup do
        @img.update_attributes(:crop=>{:x=>'0',:y=>0,:w=>'660',:h=>600})
      end

      should 'keep image valid' do
        err subject
        assert subject.valid?
      end

      should 'keep original width' do
        assert_equal 660, subject.width
      end

      should 'keep original height' do
        assert_equal 600, subject.height
      end
    end

    context 'with new file' do
      setup do
        @img.update_attributes(:file=>uploaded_jpg('flower.jpg'), :crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80})
      end

      should 'keep image valid' do
        err subject
        assert subject.valid?
      end

      should 'return new width' do
        assert_equal 800, subject.width
      end

      should 'return new height' do
        assert_equal 600, subject.height
      end

      should 'return new size' do
        assert_equal 96648,  subject.size
      end
    end
  end

  context 'Destroying' do
    setup do
      login(:tiger)
    end

    context 'an image with no iformats' do
      setup do
        @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                            :title=>'albatros', :file => uploaded_jpg('bird.jpg')) }
      end

      subject{ @img}

      should 'destroy version from database' do
        assert_difference('Version.count', -1) do
          subject.destroy
        end
      end

      should 'destroy attachment from database' do
        assert_difference('Attachment.count', -1) do
          subject.destroy
        end
      end

      should 'destroy file from file system' do
        filepath = @img.filepath
        subject.destroy
        assert !File.exist?(filepath)
      end
    end # a document

    context 'an image with iformats' do
      setup do
        @img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                            :title=>'albatros', :file => uploaded_jpg('bird.jpg')) }
        @img.file(Iformat['pv'])
        @img.file(Iformat['med'])
      end

      subject{ @img}


      should 'destroy version from database' do
        assert_difference('Version.count', -1) do
          subject.destroy
        end
      end

      should 'destroy attachment from database' do
        assert_difference('Attachment.count', -1) do
          subject.destroy
        end
      end

      should 'destroy file from file system' do
        full_path = @img.filepath
        subject.destroy
        assert !File.exist?(full_path)
      end

      should 'destroy iformat file' do
        pv_path = @img.filepath(Iformat['pv'])
        med_path = @img.filepath(Iformat['med'])
        subject.destroy
        assert !File.exist?(pv_path)
        assert !File.exist?(med_path)
      end
    end # a document
  end


  def test_set_event_at_from_exif_tags
    without_files('test.host/data/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'lake',
                                          :file => uploaded_jpg('exif_sample.jpg')) }
      assert_equal 'SANYO Electric Co.,Ltd.', img.exif['Make']

      # reload
      assert img = secure!(Image) { Image.find(img) }
      assert exif_tags = img.exif
      assert_equal 'SANYO Electric Co.,Ltd.', img.exif['Make']
      assert_equal Time.parse("1998-01-01 00:00:00"), img.exif.date_time
      assert_equal Time.parse("1998-01-01 00:00:00"), img.event_at
    end
  end

end
