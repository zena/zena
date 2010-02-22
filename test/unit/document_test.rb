require 'test_helper'
require 'fileutils'

class DocumentTest < Zena::Unit::TestCase

  self.use_transactional_fixtures = false

  context 'A newly created' do
    context 'valid Document' do
      setup { login(:ant) }
      subject do
          secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'life',
                                                    :file => uploaded_pdf('water.pdf') ) }
      end

      should 'be valid' do
        assert subject.valid?
      end

      should 'be saved in database' do
        assert !subject.new_record?
      end

      should 'save file in the filesystem' do
        assert File.exist?(subject.version.filepath)
      end

      should 'save content type in properties' do
        assert_equal 'application/pdf', subject.prop['content_type']
      end

      should 'save extension in properties' do
        assert_equal 'pdf', subject.prop['ext']
      end

      should 'save title in version' do
        assert_equal 'life', subject.version.title
      end

      should 'save filename in attachment' do
        assert_equal 'water.pdf', subject.version.attachment[:filename]
      end

      should 'save fullpath in document (node)' do
        assert_not_nil subject[:fullpath]
      end

      should 'save user_id in attachment' do
        assert_equal users_id(:ant), subject.version.attachment.user_id
      end

      should 'save site_id in attachment' do
        assert_equal sites_id(:zena), subject.version.attachment.site_id
      end
    end # Document

    context 'Document with same name' do
      setup do
        login(:tiger)
      end
      subject do
        secure!(Document) { Document.create( :parent_id => nodes_id(:cleanWater),
                                                   :title => 'lake',
                                                   :file  => uploaded_pdf('water.pdf') ) }
      end

      should 'save name with increment' do
        assert_equal 'lake-1', subject.name
      end

      should 'save version title with increment' do
        assert_equal 'lake-1', subject.version.title
      end
    end # with same name

    context 'without file' do
      setup do
        login(:ant)
      end
      subject do
        secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'lalala') }
      end

      should 'save record in the database' do
        assert !subject.new_record?
      end

      should 'save text/plain as content_type' do
        assert_equal 'text/plain', subject.content_type
      end
    end # without file

    context 'Document with content_type specified' do
      setup do
        login(:tiger)
      end
      subject do
        secure!(Document) { Document.create("content_type"=>"text/css",
                                            "parent_id"=>nodes_id(:cleanWater),
                                            :file => uploaded_text('some.txt') )}
      end

      should 'save record in the database' do
        assert !subject.new_record?
      end

      should 'save the specified content_type' do
        assert_equal 'text/css', subject.content_type
      end
    end # with content type specified

    context 'Document with a bad filename' do
      setup do
        login(:ant)
      end
      subject do
        secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
          :name => 'stupid.jpg',
          :file => uploaded_pdf('water.pdf') ) }
      end

      should 'save name and version title with the given name' do
        assert !subject.new_record?
        assert_equal "stupid", subject.name
        assert_equal "stupid", subject.version.title
      end

      should 'save filename with the name of the file' do
        assert_equal "water.pdf", subject.filename
      end
    end # Document with a bad file name
  end # A newly created


  context 'On reading' do
    setup do
      login(:tiger)
    end

    context 'a document' do

      setup do
        @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'life',
                                                   :file => uploaded_pdf('water.pdf') ) }
      end

      subject do
        secure!(Document) { Document.find( @doc ) }
      end

      should 'get filename' do
        assert_equal 'water.pdf', subject.filename
      end

      should 'get fullpath' do
        assert_equal 'projects/cleanWater/life', subject.fullpath
      end

      should 'get filepath' do
         assert_match /water.pdf/, subject.filepath
      end

      should 'get rootpath' do
          assert_equal 'zena/projects/cleanWater/life.pdf', subject.rootpath
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
      subject do
        secure!(Document) { Document.find( nodes_id(:bird_jpg) )  }
      end

      should 'know if it is an image' do
        assert subject.image?
      end
    end

  end

  context 'Finding a Document by path' do
    setup do
      login(:tiger)
      @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'SkyWater',
                                                 :file => uploaded_pdf('water.pdf') ) }
    end

    should 'return correct document' do
      doc = secure!(Document) { Document.find_by_path("projects/cleanWater/SkyWater") }
      assert_equal "projects/cleanWater/SkyWater", doc.fullpath
    end
  end

  context 'On updating' do
    setup do
      login(:tiger)
      @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'life',
                                                 :file => uploaded_pdf('water.pdf') ) }
    end

     context 'document attributes' do

       should 'save changes' do
         assert @doc.update_attributes(:title => 'hopla')
         assert_equal 'hopla', @doc.version.title
       end

       should 'not create a new attachment' do
         assert_difference('Attachment.count', 0) do
           @doc.update_attributes(:title => 'hopla')
         end
       end
     end # document attribute

     context 'the document file' do

       should 'save change' do
         assert @doc.update_attributes(:file => uploaded_pdf('forest.pdf'))
       end

       should 'not create a new attachment' do
         assert_difference('Attachment.count', 0) do
           @doc.update_attributes(:file => uploaded_pdf('forest.pdf'))
         end
       end

       should 'change filename' do
         @doc.update_attributes(:file => uploaded_pdf('forest.pdf'))
         assert_equal 'forest.pdf', @doc.filename
       end

       should 'change filepath' do
         original_filepath = @doc.filepath
         @doc.update_attributes(:file => uploaded_pdf('forest.pdf'))
         assert_not_equal original_filepath, @doc.filepath
       end
     end # document file
  end # on updating

  context 'On destroy' do
    setup do
      login(:tiger)
    end
    context 'a document' do
      setup do
        @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'Shower',
                                                   :file => uploaded_pdf('water.pdf') ) }
      end

      subject{ @doc}

      should 'destroy version from database' do
        assert_difference('Version.count', -1) do
          subject.destroy
        end
      end

      should 'destory attachment from database' do
        assert_difference('Attachment.count', -1) do
          subject.destroy
        end
      end

      should 'destroy file from file system' do
        filepath = @doc.filepath
        subject.destroy
        assert !File.exist?(filepath)
      end
    end

    context 'with many version' do
      setup do
        @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title=>'Shower',
                                                   :file => uploaded_pdf('water.pdf') ) }
        @doc.version.backup = true
        @doc.update_attributes(:title=>'Bath')
        assert_equal 2, @doc.version.number
      end
      subject{ @doc }

      should 'share attachment' do
        assert_equal subject.versions.first.attachment.id, subject.versions.last.attachment.id
      end

      should 'not destroy attachment if delete a version' do
        assert_difference('Attachment.count', 0) do
          subject.versions.first.destroy
        end
      end
    end

  end



  def test_create_with_file_name_has_dots
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report...',
                                                :file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "report...", doc.name
      assert_equal "report...", doc.version.title
      assert_equal "water.pdf", doc.filename
      assert_equal 'pdf', doc.ext
    end
  end

  def test_create_with_file_name_unknown_ext
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :file  => uploaded_fixture("some.txt", 'application/octet-stream', "super.zz") ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "super", doc.name
      assert_equal "super", doc.version.title
      assert_equal "super.zz", doc.filename
      assert_equal 'zz', doc.ext
      assert_equal 'application/octet-stream', doc.content_type
    end
  end

  def test_set_title
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :file  => uploaded_fixture('water.pdf', 'application/pdf', 'wat'), :title => "lazy waters.pdf") }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "lazyWaters", doc.name
      assert_equal "lazy waters", doc.version.title
      assert_equal "wat", doc.filename
      assert_equal 'pdf', doc.ext
      assert_equal 'application/pdf', doc.content_type
    end
  end

end
