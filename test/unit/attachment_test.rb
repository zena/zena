# Simple integration test for the Versions::Attachment
require 'test_helper'

class AttachmentTest< ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  include Zena::Use::Fixtures
  include Zena::Use::TestHelper
  include Zena::Acts::Secure
  include ::Authlogic::TestCase

  # ====================================================== Document tests
  context 'With a logged in visitor' do
    setup do
      login(:tiger)
    end

    context 'creating a document' do
      subject do
        secure!(Document) { Document.create(
          :parent_id => nodes_id(:cleanWater),
          :title     => 'life',
          :file      => uploaded_pdf('water.pdf'))
        }
      end

      should 'stat file size' do
        preserving_files("test.host/data") do
          assert_equal 29279, subject.size
        end
      end

      should 'create an attachment' do
        preserving_files("test.host/data") do
          assert_difference('Attachment.count', 1) do
            subject
          end
        end
      end

      should 'use visitor as owner for attachment' do
        preserving_files("test.host/data") do
          assert_equal users_id(:tiger), subject.version.attachment.user_id
        end
      end

      should 'set site_id on attachment' do
        preserving_files("test.host/data") do
          assert_equal sites_id(:zena), subject.version.attachment.site_id
        end
      end
    end # creating a document

    context 'updating a document' do

      subject do
        secure!(Node) { nodes(:forest_pdf) } # redaction for 'ant' in 'en'
      end

      context 'without changing file' do
        should 'not create a new attachment' do
          assert_difference('Attachment.count', 0) do
            subject.update_attributes(:title => 'hopla')
          end
        end
      end

      context 'with a new file' do
        subject do
          secure!(Node) { nodes(:bird_jpg) }
        end

        should 'create a new attachment' do
          assert_difference('Attachment.count', 1) do
            assert subject.update_attributes(:file => uploaded_png('bomb.png'))
          end
        end

        should 'change filepath' do
          subject.update_attributes(:file => uploaded_png('bomb.png'))
          assert_match /bird.png$/, subject.filepath
        end
      end

      context 'in redit time' do
        setup do
          login(:ant)
          visitor.lang = 'en'
          subject.version.created_at = Time.now
        end

        should 'update attachment' do
          preserving_files("test.host/data") do
            assert_difference('Attachment.count', 0) do
              assert subject.update_attributes(:file => uploaded_pdf('water.pdf'))
            end
          end
        end

        should 'update size' do
          preserving_files("test.host/data") do
            subject.update_attributes(:file => uploaded_pdf('water.pdf'))
            assert_equal 29279, subject.file.size
          end
        end
      end # in redit time

      context 'with many versions' do
        setup do
          login(:ant)
          visitor.lang = 'fr'
          # Create a new version in 'fr' to share attachment
          subject.update_attributes(:title => 'les arbres')
        end

        should 'share attachment' do
          assert_equal attachments_id(:forest_pdf_en), subject.version.attachment_id
        end

        should 'create a new attachment on file change' do
          preserving_files("test.host/data") do
            login(:ant)
            visitor.lang = 'en'
            node = secure!(Node) { nodes(:forest_pdf) }
            assert_difference('Attachment.count', 1) do
              assert node.update_attributes(:file => uploaded_pdf('water.pdf'))
            end
          end
        end
      end # with many versions
    end # updating a document
  end # With a logged in visitor

  # ====================================================== Image tests
  context 'Creating an image' do
    setup do
      login(:tiger)
    end

    context 'with a jpg file' do
      subject do
      end

      should 'write file to filesystem' do
        preserving_files('test.host/data') do
          image = secure!(Image) { Image.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'birdy',
            :file      => uploaded_jpg('bird.jpg'))
          }
          assert File.exist?(image.filepath)
        end
      end
    end # with a jpg file
  end # Creating an image

  context 'Updating an image' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:bird_jpg) }
    end

    context 'with a new file' do

      should 'change saved file' do
        @old_path = subject.filepath

        preserving_files('test.host/data') do
          subject.update_attributes(:file => uploaded_jpg('flower.jpg'))
          assert_not_equal File.read(@old_path), File.read(subject.filepath)
        end
      end
    end # with a new file

  end # Updating an image

  context 'Destroying' do
    setup do
      login(:tiger)
    end

    context 'an image' do
      subject do
        secure!(Node) { nodes(:bird_jpg) }
      end

      should 'destroy file from file system' do
        preserving_files('test.host/data') do
          filepath = subject.filepath
          subject.destroy
          assert !File.exist?(filepath)
        end
      end

      context 'with iformats' do
        should 'destroy version from database' do
          preserving_files('test.host/data') do
            subject.file(Iformat['pv'])
            subject.file(Iformat['med'])

            assert_difference('Version.count', -1) do
              subject.destroy
            end
          end
        end

        should 'destroy attachment from database' do
          preserving_files('test.host/data') do
            subject.file(Iformat['pv'])
            subject.file(Iformat['med'])

            assert_difference('Attachment.count', -1) do
              subject.destroy
            end
          end
        end

        should 'destroy file from file system' do
          preserving_files('test.host/data') do
            subject.file(Iformat['pv'])
            subject.file(Iformat['med'])

            full_path = subject.filepath
            subject.destroy
            assert !File.exist?(full_path)
          end
        end

        should 'destroy iformat file' do
          preserving_files('test.host/data') do
            subject.file(Iformat['pv'])
            subject.file(Iformat['med'])

            pv_path = subject.filepath(Iformat['pv'])
            med_path = subject.filepath(Iformat['med'])
            subject.destroy
            assert !File.exist?(pv_path)
            assert !File.exist?(med_path)
          end
        end
      end # with iformats
    end # an image
  end # Destroying
end
