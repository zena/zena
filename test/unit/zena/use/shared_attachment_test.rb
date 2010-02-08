require 'test_helper'

class SharedAttachmentTest < Zena::Unit::TestCase
  Attachment = Class.new(Zena::Use::SharedAttachment::Attachment) do
    def filepath
      File.join(RAILS_ROOT, 'tmp', 'attachments', super)
    end
  end

  # Mock a document class with many versions
  class Document < ActiveRecord::Base
    include Zena::Use::MultiVersion

    set_table_name :nodes
    before_save :set_dummy_defaults

    def title=(title)
      version.title = title
    end

    def file=(file)
      version.file = file
    end

    def version
      @version ||= new_record? ? versions.build : versions.first(:order => 'id DESC')
    end
    private
      def set_dummy_defaults
        self[:user_id] ||= 0
      end
  end

  # Mock a version class with shared attachments (between versions of the same document)
  class Version < ActiveRecord::Base
    include Zena::Use::MultiVersion::Version
    include Zena::Use::AutoVersion
    include Zena::Use::SharedAttachment
    set_attachment_class 'SharedAttachmentTest::Attachment'
    set_table_name :versions

    def should_clone?
      true
    end

    private
      def setup_version_on_create
        # Dummy values when testing Version without a Document
        self[:node_id] ||= 0
        self[:user_id] ||= 0
        self[:status]  ||= 0
      end
  end

  context 'When creating a new owner' do
    setup do
      @owner = Version.create(:file => uploaded_jpg('bird.jpg'))
    end

    should 'store file in the filesystem' do
      assert File.exist?(@owner.filepath)
      assert_equal uploaded_jpg('bird.jpg').read, File.read(@owner.filepath)
    end

    should 'restore the filepath from the database' do
      attachment = Attachment.find(@owner.attachment_id)
      assert_equal @owner.filepath, attachment.filepath
    end
  end

  context 'On an owner with a file' do
    setup do
      @owner = Version.create(:file => uploaded_jpg('bird.jpg'))
      @owner = Version.find(@owner.id)
    end

    should 'remove file in the filesystem when updating file' do
      old_filepath = @owner.filepath
      puts "Start"
      assert_difference('Attachment.count', 0) do # destroy + create
        assert @owner.update_attributes(:file => uploaded_jpg('lake.jpg'))
      end
      assert_not_equal old_filepath, @owner.filepath
      assert File.exist?(@owner.filepath)
      assert_equal uploaded_jpg('lake.jpg').read, File.read(@owner.filepath)
      assert !File.exist?(old_filepath)
    end
  end

  context 'Updating document' do
    setup do
      begin
        @doc = Document.create(:title => 'birdy', :file => uploaded_jpg('bird.jpg'))
      rescue => err
        puts err.message
        puts err.backtrace.join("\n")
      end
    end

    # Updating document ...attributes
    context 'attributes' do
      setup do
        assert_difference('Version.count', 1) do
          @doc.update_attributes(:title => 'hopla')
        end
      end

      should 'reuse the same filepath in new versions' do
        filepath = nil
        @doc.versions.each do |version|
          if filepath
            assert_equal filepath, version.filepath
          else
            filepath = version.filepath
          end
        end
      end
    end

    # Updating document ...file
    context 'file' do
      setup do
        assert_difference('Version.count', 1) do
          @doc.update_attributes(:file => uploaded_jpg('lake.jpg'))
        end
      end

      should 'create new filepath' do
        filepath = nil
        @doc.versions.each do |version|
          if filepath
            assert_not_equal filepath, version.filepath
          else
            filepath = version.filepath
          end
        end
      end
    end # Updating document .. file
  end # Updating document

  context 'On a document with many versions' do
    setup do
      assert_difference('Version.count', 2) do
        @doc = Document.create(:title => 'birdy', :file => uploaded_jpg('bird.jpg'))
        @doc.update_attributes(:title => 'Vögel')
        @doc = Document.find(@doc.id)
      end
    end

    context 'removing a version' do

      should 'not remove shared attachment' do
        filepath = @doc.version.filepath

        assert_difference('Version.count', -1) do
          assert_difference('Attachment.count', 0) do
            assert @doc.version.destroy
          end
        end
        assert File.exist?(filepath)
      end
    end

    context 'removing the last version' do

      should 'remove shared attachment' do
        filepath = @doc.version.filepath

        assert_difference('Version.count', -2) do
          assert_difference('Attachment.count', -1) do
            @doc.versions.each do |version|
              assert version.destroy
            end
          end
        end
        assert !File.exist?(filepath)
      end
    end
  end

  private
    def filepath(attachment_id, filename)
      digest = Digest::SHA1.hexdigest(attachment_id.to_s)
      "#{digest[0..0]}/#{digest[1..1]}/#{filename}"
    end
end