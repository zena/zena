# Simple integration test for the Versions::Attachment
require 'test_helper'

class AttachmentTest< ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  include Zena::Use::Fixtures
  include Zena::Use::TestHelper
  include Zena::Acts::Secure
  include ::Authlogic::TestCase

  context 'With a logged in visitor' do
    setup do
      login(:tiger)
    end

    context 'updating a document' do

      subject do
        secure!(Node) { nodes(:forest_pdf) } # redaction for 'ant' in 'en'
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
end
