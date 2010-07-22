require 'test_helper'

class ImageTest < Zena::Unit::TestCase

  context 'The Image class' do
    context 'receiving accept_content_type' do
      should 'accept image/jpeg' do
        assert Image.accept_content_type?('image/jpeg')
      end

      should 'not accept application/pdf' do
        assert !Image.accept_content_type?('application/pdf')
      end
    end
  end # The Image class

  context 'Creating an image' do
    setup do
      login(:tiger)
    end

    context 'with a jpg file' do
      subject do
        secure!(Image) { Image.create(
          :parent_id => nodes_id(:cleanWater),
          :title     => 'birdy',
          :file      => uploaded_jpg('bird.jpg'))
        }
      end

      should 'be saved in the database' do
        assert !subject.new_record?
      end

      should 'be valid' do
        assert subject.valid?
      end

      should 'get width and height from file' do
        assert_equal 660, subject.width
        assert_equal 600, subject.height
      end

      should 'get extension from file' do
        assert_equal 'jpg', subject.ext
      end

      should 'get content type from file' do
        assert_equal 'image/jpeg', subject.content_type
      end

      should 'build an attachment' do
        assert_difference('Attachment.count', 1) do
          subject
        end
      end

      should 'build a new version' do
        assert_difference('Version.count', 1) do
          subject
        end
      end

      should 'build filepath from title' do
        assert_match /birdy.jpg/, subject.filepath
      end
      
      should 'save default text' do
        node = secure(Node) { Node.find(subject.id) }
        assert_equal "!#{subject.zip}!", node.text
      end

      # should 'write file to filesystem' do
      # Moved to Attachment test (no transactional fixtures)

    end # with a jpg file

    context 'with a file with exif tags' do
      setup do
        login(:tiger)
      end

      subject do
        secure!(Image) { Image.create(
          :parent_id => nodes_id(:cleanWater),
          :title     => 'lake',
          :file      => uploaded_jpg('exif_sample.jpg'))
        }
      end

      should 'read Make from exif data' do
        assert_equal 'SANYO Electric Co.,Ltd.', subject.exif['Make']
      end

      should 'save exif data in database' do
        subject.reload
        assert_equal 'SANYO Electric Co.,Ltd.', subject.exif['Make']
      end

      should 'save exif data in exif prop' do
        assert_kind_of ExifData, subject.prop['exif']
      end

      should 'parse time values' do
        assert_equal Time.parse("1998-01-01 00:00:00"), subject.exif.date_time
      end

      should 'use exif date_time as event_at' do
        assert_equal Time.parse("1998-01-01 00:00:00"), subject.event_at
      end
    end # with a file with exif tags
  end # Creating an image

  context 'An image' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:bird_jpg) }
    end

    context 'with a given image format' do
      setup do
        @pv = Iformat['pv']
      end

      should 'return calculated width and height for format' do
        assert_equal 70, subject.width(@pv)
        assert_equal 70, subject.width(@pv)
      end

      should 'create a new file in a folder named after the format' do
        assert_match /pv/, subject.filepath(@pv)
      end

      should 'return the original path by default' do
        assert_match /full/, subject.filepath
      end

      should 'create a new file corresponding to the new format on file' do
        preserving_files('test.host/zafu') do
          subject.file(@pv)
          assert File.exist?( subject.filepath(@pv) )
        end
      end

      should 'return a file corresponding to the format' do
        preserving_files('test.host/zafu') do
          assert_kind_of File, subject.file(@pv)
        end
      end

      should 'not create a version' do
        assert_difference('Version.count', 0) do
          assert_difference('Attachment.count', 0) do
            preserving_files('test.host/zafu') do
              subject.file(@pv)
            end
          end
        end
      end
    end # with a given image format

    context 'without an image format' do
      should 'return full resolution on width and height' do
        assert_equal 660, subject.width
        assert_equal 600, subject.height
      end

      should 'return original file size' do
        assert_equal 56243, subject.size
      end
    end

    should 'return content_type' do
      assert_equal 'image/jpeg', subject.content_type
    end
  end # An image

  context 'Updating an image' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:bird_jpg) }
    end

    context 'with a new title' do
      should 'not change filepath' do
        filepath1 = subject.filepath
        assert subject.update_attributes(:title => 'Milan')
        assert_equal filepath1, subject.filepath
      end
    end # with a new title

    context 'with a new file' do
      setup do
        subject.update_attributes(:file => uploaded_jpg('flower.jpg'))
      end

      should 'be valid' do
        assert subject.valid?
      end

      should 'be saved in the database' do
        assert !subject.new_record?
      end

      should 'not change file name' do
        assert_equal 'bird.jpg', subject.filename
      end

      should 'not change filepath' do
        assert_match /bird.jpg/, subject.filepath
      end

      should 'change width' do
        assert_equal 800, subject.width
      end

      should 'change height' do
        assert_equal 600, subject.height
      end

      should 'change size' do
        assert_equal 96648, subject.size
      end

      # should 'change saved file'
      # Moved to Attachment test (no transactional fixtures)

    end # with a new file

    context 'with a document file' do
      setup do
        subject.update_attributes(:file => uploaded_text('some.txt'))
      end

      should 'add an error on file' do
        assert_equal 'incompatible with this class', subject.errors[:file]
      end

      should 'not change content type' do
        assert 'image/jpeg', subject.content_type
      end

      should 'not change file name' do
        assert 'flower.jpg', subject.filename
      end

      should 'not change file path' do
        image = secure!(Node) { Node.find(subject.id) }
        assert_match /bird.jpg/, image.filepath
      end

      should 'not create a version' do
        assert_difference('Version.count', 0) do
          subject
        end
      end
    end # with a document file

    context 'by cropping' do
      context 'with x, y, w, h' do
        subject do
          secure!(Node) { nodes(:bird_jpg) }.tap do |n|
            n.update_attributes(
              :crop => {:x => '500', :y => 30, :w => '180', :h => 80}
            )
          end
        end

        should 'save a new version' do
          assert_difference('Version.count', 1) do
            subject
          end
        end

        should 'clip and modify width from x and w' do
          # 660 - 500 = 160
          # 160 = min(160, 180)
          assert_equal 160, subject.width
        end

        should 'clip and modify height from y and h' do
          # 600 - 30 = 570
          # 80 = min(570, 80)
          assert_equal 80, subject.height
        end
      end # with x,y,w,h

      context 'with max size' do

        setup do
          subject.update_attributes(
            :crop => {'max_value' => '30', 'max_unit' => 'Kb'}
          )
        end

        should 'reduce file size' do
          assert subject.valid?
          assert subject.size < 30 * 1024 * 1.2
        end
      end # with limitation

      context 'with a format' do
        setup do
          subject.update_attributes(:crop => {:format => 'png'})
        end

        should 'change type' do
          assert_equal 'image/png', subject.content_type
          assert_equal 'png', subject.ext
        end
      end # with a format


      context 'with same size' do
        setup do
          subject.update_attributes(
            :crop => {:x => '0', :y => 0, :w => '660', :h => 600 }
          )
        end

        should 'not change version' do
          assert_difference('Version.count', 0) do
            subject
          end

          assert_equal 660, subject.width
          assert_equal 600, subject.height
        end
      end # with same size

      context 'with a new file' do

        should 'change file and crop' do
          assert_difference('Version.count', 1) do
            subject.update_attributes(
              :file => uploaded_jpg('flower.jpg'),
              :crop => {:x => '500', :y => 30, :w =>'200',:h => 80}
            )
            assert_equal 800, subject.width
            assert_equal 600, subject.height
            assert_equal 96648,  subject.size
          end
        end
      end # with new file
    end # by cropping
  end # Updating an image

  context 'Destroying' do
    setup do
      login(:tiger)
    end

    context 'an image' do
      subject do
        secure!(Node) { nodes(:bird_jpg) }
      end

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

      # should 'destroy file from file system'
      # Moved to Attachment test (no transactional fixtures)

      # context 'with iformats'
      # Moved to Attachment test (no transactional fixtures)

    end # an image
  end # Destroying
end # ImageTest

