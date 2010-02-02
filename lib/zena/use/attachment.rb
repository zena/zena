module Zena
  module Use

    # The attachement module provides shared file attachments to a class with a copy-on-write
    # pattern.
    # Basically the module provides 'file=' and 'file' methods.
    module Attachment
    end
  end
end
=begin
      module Version
        def file=(file)
          if attachment = self.attachment
            attachment.unlink!
          end
          attachment = new Attachment(file)
        end

        def filepath
          attachment.filepath
        end
      end
    end
  end
end

module Zena
  class Attachment
    def initialize(file)
      @file = file
      self[:filepath] = build_unique_filepath
    end

    def unlink!
      # mark as needing file deletion
    end

    # Triggered from node when all save operations ok.
    def write_file
      File.write...
    end

    def build_unique_filepath
      name = @file.original_filename
      @uuid = UUIDTools::UUID.random_create.to_s.gsub('-','')[0..30]
      digest = Digest::SHA1.hexdigest(@uuid)
      # make sure name is not corrupted
      fname = name.gsub(/[^a-zA-Z\-_0-9]/,'')
      # "#{digest[0..0]}/#{digest[1..1]}/#{fname}"

    end
  end
end


# API

context 'Creating a new document' do
  setup do
    @node = Document.create(:file => uploaded_jpg(...))
  end

  should 'store file in the filesystem' do
    assert File.exist?(@node.version.filepath)
  end

  should 'store the path in the database' do
    @node = Document.find(@node.id) # reload
    assert_equal 'xxxx', @node.version.filepath
  end
end

context 'Updating document attributes' do
  setup do
    @node.update_attributes(:title => 'hopla')
  end

  should 'reuse the same filepath in redactions' do
    filepath = nil
    @node.versions.each do |version|
      if filepath
        assert_equal filepath, version.filepath
      else
        filepath = version.filepath
      end
    end
  end
end

context 'Updating document file' do
  setup do
    @node = secure!(Node) { nodes(:bird) }
    assert @node.update_attributes(:file => uploaded_jpg(...))
  end

  should 'create new filepath' do
    filepath = nil
    @node.versions.each do |version|
      if filepath
        assert_not_equal filepath, version.filepath
      else
        filepath = version.filepath
      end
    end
  end
end

context 'Removing document versions' do
  setup do
  end

  should 'delete files when they are not used anymore' do
  end
end












=end