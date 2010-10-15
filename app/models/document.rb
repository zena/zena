=begin rdoc
A Document is a node with a file.

=== File storage

There can be one file per version but when a new version created without a new file, the new version uses the same file as the original:

 original version -------> file1   (this file cannot be changed)
                            /
 new version      ---------/       (we can add a new file here)

We cannot change the original file but we can add a new file to the new version:

 original version -------> file1   (this file can now be changed)

 new version      -------> file2   (this file can be changed too)

This is to prevent a published file (file1 for example) to be changed during a redaction.

File data is kept in a directory in +sites/<host>/data/<ext>/<version_id>/<filename>+. This makes it possible to retrieve the data in case the database goes havoc.

=== Version

The version class used by documents is the DocumentVersion.

=== Content

Content (file data) is managed by the DocumentContent. This class is responsible for storing the file and retrieving the data. It provides the following attributes to the Document :

 size::  file size
 ext::   file extension
 content_type:: file content-type
=end
# should be a sub-class of Node, not Page (#184). Write a migration, fix fixtures and test.
class Document < Node

  include Versions::Attachment
  store_attachments_in :version,  :attachment_class => 'Attachment'

  property do |p|
    p.integer 'size'
    p.string  'content_type'
    p.string  'ext'
  end

  safe_property :size, :content_type, :ext
  safe_method   :filename => String, :file => File, :filepath => String

  validate          :make_unique_title
  validate          :valid_file
  validate          :valid_content_type
  after_save        :clear_new_file

  class << self

    def version_class
      DocumentVersion
    end

    alias o_new new

    # Return a new Document or a sub-class of Document depending on the file's content type. Returns a TextDocument if there is no file.
    def new(attrs = {})
      scope = self.scoped_methods[0] || {}

      attrs = attrs.stringify_keys
      file  = attrs['file'] || ((attrs['version_attributes'] || {})['content_attributes'] || {})['file']
      if attrs['content_type']
        content_type = attrs['content_type']
      elsif file && file.respond_to?(:content_type)
        content_type = file.content_type
      elsif ct = attrs['content_type']
        content_type = ct
      elsif attrs['title'] =~ /^.*\.(\w+)$/ && types = Zena::EXT_TO_TYPE[$1.downcase]
        content_type = types[0]
      end

      klass = document_class_from_content_type(content_type)

      attrs['content_type'] = content_type

      if klass != self
        klass.with_scope(scope) { klass.o_new(attrs) }
      else
        klass.o_new(attrs)
      end
    end

    # Compatibility with VirtualClass
    alias new_instance new

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Document', :without => 'Image')
    end

    # Return document class and content_type from content_type
    def document_class_from_content_type(content_type)
      if content_type
        if Image.accept_content_type?(content_type)
          Image
        elsif Template.accept_content_type?(content_type)
          Template
        elsif TextDocument.accept_content_type?(content_type)
          TextDocument
        else
          self
        end
      elsif self == Document
        # no content_type means no file. Only TextDocuments can be created without files
        TextDocument
      else
        self
      end
    end

    # Return true if the content_type can change independantly from the file
    def accept_content_type_change?
      false
    end
  end # class << self

  # Create an attachment with a file in file system. Create a new version if file is updated.
  def file=(new_file)
    if new_file = super(new_file)
      self.size = new_file.kind_of?(StringIO) ? new_file.size : new_file.stat.size
      @new_file = new_file
    end
  end

  # Return the file size.
  def size(mode=nil)
    if prop['size']
      prop['size']
    elsif !new_record? && File.exist?(self.filepath)
      prop['size'] = File.size(self.filepath)
      self.save
      prop['size']
    end
  end

  # Return true if the document is an image.
  def image?
    kind_of?(Image)
  end

  # Get the document's public filename using the name and the file extension.
  # FIXME: shouldn't we use title here ?
  def filename
    version.attachment.filename
  end

  # Get the file path defined in attachment.
  def filepath(format=nil)
    version.attachment.filepath(format)
  end

  protected
    def set_defaults
      set_defaults_from_file

      self.ext = get_extension if self.ext.blank? || @new_file

      if title.to_s =~ /\A(.*)\.#{self.ext}$/i
        self.title = $1
      end

      super

      set_attachment_filename
      true
    end

    # Overwriten in TextDocument
    def set_attachment_filename
      if @new_file
        version.attachment.filename = "#{title}.#{ext}"
      end
    end

    # Make sure we have a file.
    def valid_file
      if new_record? && !@new_file
        errors.add('file', "can't be blank")
        false
      else
        true
      end
    end

    # Make sure the new file
    def valid_content_type
      return true unless prop.content_type_changed?

      if !@new_file && !self.class.accept_content_type_change?
        errors.add('content_type', 'incompatible with this file')
        return false
      end

      klass = Document.document_class_from_content_type(content_type)

      if klass != self.class
        if @new_file
          errors.add('file', 'incompatible with this class')
        else
          errors.add('content_type', 'incompatible with this class')
        end
      end
    end

    def clear_new_file
      @new_file = nil
      true
    end

    def set_defaults_from_file
      return unless @new_file
      self.content_type = @new_file.content_type unless prop.content_type_changed?

      if base = @new_file.original_filename
        self.title = base if title.blank?
      end
    end

    # Make sure title is unique. This should be run after prop_eval.
    def make_unique_title
      get_unique_title_in_scope('ND')
    end

    def get_extension
      extensions = Zena::TYPE_TO_EXT[prop['content_type']]
      if extensions && content_type != 'application/octet-stream' # use 'bin' extension only if we do not have any other ext.
        (prop['ext'] && extensions.include?(prop['ext'].downcase)) ? self.prop['ext'].downcase : extensions[0]
      elsif @new_file
        # unknown content_type or 'application/octet-stream', just keep the extension we have
        if @new_file.original_filename =~ /\w\.(\w+)$/
          $1.downcase
        else
          'bin'
        end
      else
        nil
      end
    end

end