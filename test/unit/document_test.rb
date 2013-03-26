require 'test_helper'
require 'fileutils'

class DocumentTest < Zena::Unit::TestCase

  context 'Finding class from content_type' do
    should 'return self on unknown content_type' do
      class Dummy < Document
      end
      assert_equal 'DocumentTest::Dummy', Dummy.document_class_from_content_type('zorglub').to_s
    end

    should 'return Image on image types' do
      assert_equal 'Image', Document.document_class_from_content_type('image/png').to_s
    end
    
    should 'not return Image on svg' do
      assert_equal 'TextDocument', Document.document_class_from_content_type('image/svg+xml').to_s
    end

    should 'return TextDocument on nil' do
      assert_equal 'TextDocument', Document.document_class_from_content_type(nil).to_s
    end
    
    should 'return matching content_type sub-class' do
      login(:lion)
      secure(VirtualClass) {
        VirtualClass.create(
          :superclass      => 'TextDocument',
          :name            => 'HtmlDoc',
          :create_group_id => groups_id(:public), 
          :content_type    => 'text/html'
        )}
      assert_equal VirtualClass['HtmlDoc'], Document.document_class_from_content_type('text/html')  
      assert_equal VirtualClass['TextDocument'], Document.document_class_from_content_type('text/plain')
    end
  end

  context 'With a logged in user' do
    setup do
      login(:ant)
    end

    context 'creating a document' do
      subject do
        secure!(Document) { Document.create(
          :parent_id => nodes_id(:cleanWater),
          :file      => uploaded_pdf('water.pdf', 'life'))
        }
      end

      should 'create a new Document' do
        assert_difference('Node.count', 1) do
          assert !subject.new_record?
          assert_kind_of Document, subject
        end
      end

      should 'set content_type' do
        assert_equal 'application/pdf', subject.content_type
      end

      should 'set extension' do
        assert_equal 'pdf', subject.ext
      end

      should 'set title from original_filename' do
        assert_equal 'life', subject.title
      end

      context 'with same title' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :file      => uploaded_pdf('water.pdf'))
          }
        end

        should 'save title with increment' do
          assert_equal 'water-1', subject.title
        end
      end # with same title

      context 'without a file' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'Adam & Steve')
          }
        end

        should 'save text/plain as content_type' do
          assert !subject.new_record?
          assert_equal 'text/plain', subject.content_type
        end
      end # without a file

      context 'with content_type specified' do
        subject do
          secure!(Document) { Document.create(
            :parent_id    => nodes_id(:cleanWater),
            :content_type => 'text/css',
            :file         => uploaded_text('some.txt'))
          }
        end

        should 'save the specified content_type' do
          assert !subject.new_record?
          assert_equal 'text/css', subject.content_type
        end
      end # with content_type

      context 'with a wrong extension in title' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'stupid.jpg',
            :file      => uploaded_pdf('water.pdf'))
          }
        end

        should 'fix extension but use title' do
          err subject
          assert !subject.new_record?
          assert_equal 'pdf', subject.ext
          assert_equal 'stupid.jpg', subject.title
          assert_equal 'stupid.jpg.pdf', subject.filename
        end
      end # with wrong extension in title

      context 'with title ending with dots' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'report...',
            :file      => uploaded_pdf('water.pdf'))
          }
        end

        should 'keep dots in title' do
          assert_equal 'report...', subject.title
        end

        should 'append extension afert dots' do
          assert_equal 'report....pdf', subject.filename
        end

        should 'extract extension from file' do
          assert_equal 'pdf', subject.ext
        end
      end # with title ending with dots

      context 'with an unknown extension' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'report...',
            :file      => uploaded_fixture('some.txt', 'application/octet-stream', 'super.zz'))
          }
        end

        should 'build a Document' do
          assert_equal Document, subject.class
        end

        should 'keep extension' do
          assert_equal 'zz', subject.ext
        end

        should 'use application/octet-stream as content_type' do
          assert_equal 'application/octet-stream', subject.content_type
        end
      end # with an unknown extension

      context 'without an extension' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => 'report...',
            :file      => uploaded_fixture('some.txt', 'application/octet-stream', 'super'))
          }
        end

        should 'build a Document' do
          assert_equal Document, subject.class
        end

        should 'use bin extension' do
          assert_equal 'bin', subject.ext
        end

        should 'use application/octet-stream as content_type' do
          assert_equal 'application/octet-stream', subject.content_type
        end
      end # without an extension

      context 'with an extension in title' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :title     => "lazy waters.sop",
            :file      => uploaded_fixture('water.pdf', 'application/pdf', 'wat'))
          }
        end

        should 'use file content_type to get extension' do
          assert_equal 'pdf', subject.ext
        end

        should 'use file content_type to get content_type' do
          assert_equal 'application/pdf', subject.content_type
        end

        should 'not remove ext from title' do
          assert_equal 'lazy waters.sop', subject.title
        end
      end # with an extension in title
    end # creating a document

    context 'updating a document' do
      subject do
        secure(Node) { nodes(:bird_jpg) }
      end

      context 'with a wrong file type' do
        should 'not save and set an error on file' do
          assert !subject.update_attributes(:file => uploaded_pdf('water.pdf'))
          assert_equal 'incompatible with this class', subject.errors[:file]
        end
      end # with a wrong file type

      context 'with existing title' do
        should 'save title with increment' do
          assert subject.update_attributes(:title => 'flower', :v_status => Zena::Status::Pub)
          assert_equal 'flower-1', subject.title
        end
      end # with existing title

      context 'with a new file' do
        # All tests relying on commit (filename, size, attachment) have been
        # moved to AttachmentTest.
        should 'save change' do
          assert subject.update_attributes(:file => uploaded_jpg('tree.jpg'))
        end

        should 'change filepath' do
          original_filepath = subject.filepath
          subject.update_attributes(:file => uploaded_jpg('tree.jpg'))
          assert_not_equal original_filepath, subject.filepath
        end

        context 'with different content-type' do
          setup do
            subject.update_attributes(:file => uploaded_png('bomb.png'))
          end

          should 'change content type' do
            assert_equal 'image/png', subject.content_type
          end

          should 'change filename' do
            assert_equal 'bird.png', subject.filename
          end
        end # with different content-type
      end # with a new file

      context 'with a new title' do
        should 'save title changes' do
          assert subject.update_attributes(:title => 'hopla')
          assert_equal 'hopla', subject.title
        end

        should 'change filename' do
          assert subject.update_attributes(:title => 'hopla')
          assert_equal 'hopla.jpg', subject.filename
        end
        
        should 'not change filepath' do
          assert subject.update_attributes(:title => 'hopla')
          assert_match /bird\.jpg$/, subject.filepath
        end

        should 'not alter content_type' do
          subject.update_attributes(:title => 'New title')
          assert_equal 'image/jpeg', subject.content_type
        end
      end

      context 'with a wrong content type' do
        should 'not save and set an error on content_type' do
          assert !subject.update_attributes(:content_type => 'image/png')
          assert_equal 'incompatible with this file', subject.errors[:content_type]
        end
      end # with a wrong content type
    end # updating a document

    context 'accessing a document' do

      subject do
        secure!(Document) { nodes(:water_pdf) }
      end

      should 'be valid' do
        assert subject.valid?
      end

      should 'get title' do
        assert_equal 'water', subject.title
      end

      should 'get filename' do
        assert_equal 'water.pdf', subject.filename
      end

      should 'get filepath' do
         assert_match /water.pdf$/, subject.filepath
      end

      should 'get the file size' do
        assert_equal 29279, subject.size
      end

      should 'know if it is an image' do
        assert !subject.image?
      end

      should 'get content_type' do
        assert_equal 'application/pdf', subject.content_type
      end

      should 'get file extension' do
        assert_equal 'pdf', subject.ext
      end

      should 'have a version' do
        assert_not_nil subject.version
      end

      should 'have a a version with attachment' do
        assert_not_nil subject.version.attachment
      end
    end # accessing a document

    context 'accessing an image' do
      subject do
        secure!(Document) { Document.find(nodes(:bird_jpg)) }
      end

      should 'know if it is an image' do
        assert subject.image?
      end
    end

    should 'find document by path' do
      subject = secure(Document) { Document.find_by_path("projects list/Clean Water project/water") }
      assert_kind_of Document, subject
      assert_equal nodes_id(:water_pdf), subject.id
    end
  end # With a logged in user

  context 'Destroying a document' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Node) { nodes(:water_pdf) }
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

    # ???
    # context 'an updated file' do
    #   setup do
    #     subject.update_attributes(:file => uploaded_text('some.txt'))
    #     deb subject.filepath
    #     assert_equal 'some.txt', subject.filename
    #     assert_match /some.txt/, subject.filepath
    #   end
    #
    #   should 'destroy the second file' do
    #     # ??
    #   end
    # end # an updated file


    context 'with many version' do
      setup do
        @doc = secure!(Document){ Document.find(nodes(:water_pdf))}
        @doc.version.backup = true
        @doc.update_attributes(:title=>'Bath')
        assert_equal 2, @doc.version.number
      end

      subject{ @doc }

      should 'share attachment' do
        assert_equal subject.versions.first.attachment.id, subject.versions.last.attachment.id
      end

      should 'not destroy attachment if it delete a version' do
        assert_difference('Attachment.count', 0) do
          subject.versions.first.destroy
        end
      end
    end # with many versions
  end # Destroying a document
end
