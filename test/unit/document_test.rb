require 'test_helper'
require 'fileutils'

class DocumentTest < Zena::Unit::TestCase

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

      should 'set node_name from original_filename' do
        assert_equal 'life', subject.node_name
      end

      should 'set title from original_filename' do
        assert_equal 'life', subject.node_name
      end

      context 'with same node_name' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :file      => uploaded_pdf('water.pdf'))
          }
        end

        should 'save node_name and title with increment' do
          assert_equal 'water-1', subject.node_name
          assert_equal 'water-1', subject.title
        end
      end # with same node_name

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

      context 'with a wrong extension in node_name' do
        subject do
          secure!(Document) { Document.create(
            :parent_id => nodes_id(:cleanWater),
            :node_name => 'stupid.jpg',
            :file      => uploaded_pdf('water.pdf'))
          }
        end

        should 'fix extension but use node_name' do
          err subject
          assert !subject.new_record?
          assert_equal 'pdf', subject.ext
          assert_equal 'stupid', subject.node_name
          assert_equal 'stupid', subject.title
          assert_equal 'stupid.pdf', subject.filename
        end
      end
    end # creating a document

    context 'updating a document' do
      subject do
        secure(Node) { nodes(:bird_jpg) }
      end

      context 'with a wrong file type' do
        should 'not save and set an error on file' do
          assert !subject.update_attributes( :file => uploaded_pdf('water.pdf') )
          assert_equal '', subject.errors[:file]
        end
      end # with a wrong file type

      context 'with same node_name' do
        should 'save node_name and title with increment' do
          assert subject.update_attributes( :node_name => 'water')
          assert_equal 'water-1', subject.node_name
          assert_equal 'water-1', subject.title
        end
      end # with same node_name
    end # updating a document
  end # With a logged in user

  context 'On reading' do
    setup do
      login(:tiger)
    end

    context 'a document' do

      subject do
        secure!(Document) {Document.find(nodes(:water_pdf))}
      end

      should 'be valid' do
        assert  subject.valid?
      end

      should 'get document node_name' do
        assert_equal 'water', subject.node_name
      end

      should 'get document title' do
        assert_equal 'water', subject.title
      end

      should 'get filename' do
        assert_equal 'water.pdf', subject.filename
      end

      should 'get fullpath' do
        assert_equal 'projects/cleanWater/water', subject.fullpath
      end

      should 'get filepath' do
         assert_match /water.pdf/, subject.filepath
      end

      should 'get rootpath' do
          assert_equal 'zena/projects/cleanWater/water.pdf', subject.rootpath
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
    end # a document

    context 'an image' do

      subject{ secure!(Document){ Document.find(nodes(:bird_jpg))} }

      should 'know if it is an image' do
        assert subject.image?
      end
    end
  end # On reading

  context 'Finding a Document by path' do
    setup do
      login(:tiger)
    end


    should 'return correct document' do
      doc = secure!(Document) { Document.find_by_path("projects/cleanWater/water") }
      assert_equal "projects/cleanWater/water", doc.fullpath
    end
  end

  context 'On updating' do
    setup do
      login(:tiger)
    end

    subject do
      secure!(Document){ Document.find(nodes(:water_pdf))}
    end


     context 'document attributes' do
       should 'save title changes' do
         assert subject.update_attributes(:title => 'hopla')
         assert_equal 'hopla', subject.title
       end

       should 'change document node_name when title change' do
         subject.update_attributes(:title => 'hopla')
         assert_equal 'hopla', subject.node_name
       end

       should 'not alter content_type' do
         subject.update_attributes(:title => "New title")
         assert_equal 'application/pdf', subject.content_type
       end

       should 'not create a new attachment' do
         assert_difference('Attachment.count', 0) do
           subject.update_attributes(:title => 'hopla')
         end
       end
     end # document attribute

     context 'document file' do
       should 'save change' do
         assert subject.update_attributes(:file => uploaded_pdf('forest.pdf'))
       end

       should 'change filename' do
         subject.update_attributes(:file => uploaded_pdf('forest.pdf'))
         assert_equal 'forest.pdf', subject.filename
       end

       should 'change filepath' do
         original_filepath = subject.filepath
         subject.update_attributes(:file => uploaded_pdf('forest.pdf'))
         assert_not_equal original_filepath, subject.filepath
       end

       context 'with different content-type' do
         setup{  subject.update_attributes(:file => uploaded_text('some.txt')) }

         should 'change content type' do
           assert_equal 'text/plain', subject.content_type
         end

         should 'change filename' do
           assert_equal 'some.txt', subject.filename
         end

         should 'change filepath' do
           assert_match /some.txt/, subject.filepath
         end

         should 'change size' do
           assert_equal subject.size, File.size(subject.filepath)
         end
       end # with different content-type
     end # document file
  end # on updating

  context 'On destroy' do
    setup do
      login(:tiger)
    end
    context 'a document' do

      subject{ secure!(Document){ Document.find(nodes(:water_pdf))} }

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
        filepath = subject.filepath
        subject.destroy
        assert !File.exist?(filepath)
      end
    end # a document

    context 'an updated file' do
      setup do
        subject.update_attributes(:file=>uploaded_text('some.txt'))
        assert_equal 'some.txt', subject.filename
        assert_match /some.txt/, subject.filepath
      end

      should 'destroy the second file' do

      end
    end # an updated file


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
  end # On destroy



  def test_create_with_file_name_has_dots
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create(
        :parent_id => nodes_id(:cleanWater),
        :node_name => 'report...',
        :file      => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "report...", doc.node_name
      assert_equal "report...", doc.version.title
      assert_equal "water.pdf", doc.filename
      assert_equal 'pdf', doc.ext
    end
  end

  def test_create_with_file_name_unknown_ext
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create(
        :parent_id => nodes_id(:cleanWater),
        :file      => uploaded_fixture("some.txt", 'application/octet-stream', "super.zz") ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "super", doc.name
      assert_equal "super", doc.version.title
      assert_equal "super.zz", doc.filename
      assert_equal 'bin', doc.ext
      assert_equal 'application/octet-stream', doc.content_type
    end
  end

  def test_set_title
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create(
        :parent_id => nodes_id(:cleanWater),
        :file      => uploaded_fixture('water.pdf', 'application/pdf', 'wat'), :title => "lazy waters.pdf") }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "lazy waters", doc.node_name
      assert_equal "lazy waters", doc.version.title
      assert_equal "wat", doc.filename
      assert_equal 'pdf', doc.ext
      assert_equal 'application/pdf', doc.content_type
    end
  end

end
