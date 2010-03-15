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

c_size::  file size
c_ext::   file extension
c_content_type:: file content-type
=end
# should be a sub-class of Node, not Page (#184). Write a migration, fix fixtures and test.
class Document < Node

  include Versions::Attachment
  store_attachments_in :version,  :attachment_class => 'Attachment'

  property do |t|
    t.string  "type"
    t.string  "content_type"
    t.string  "ext"
    t.integer "size"
    t.integer "width"
    t.integer "height"
    t.text    "exif_json"
    #t.string  "name"
  end

  safe_method :filename => String, :size => Number, :name => String, :content_type => String, :ext => String, :file => File, :filepath => String

  class << self

    def version_class
      DocumentVersion
    end

    alias o_new new

    # Return a new Document or a sub-class of Document depending on the file's content type. Returns a TextDocument if there is no file.
    def new(attrs = {})

      scope = self.scoped_methods[0] || {}
      klass = self
      attrs = attrs.stringify_keys
      file  = attrs['file'] || ((attrs['version_attributes'] || {})['content_attributes'] || {})['file']
      if attrs['content_type']
        content_type = attrs['content_type']
      elsif file && file.respond_to?(:content_type)
        content_type = file.content_type
      elsif ct = attrs['content_type'] || ((attrs['version_attributes'] || {})['content_attributes'] || {})['content_type']
        content_type = ct
      elsif attrs['name'] =~ /^.*\.(\w+)$/ && types = Zena::EXT_TO_TYPE[$1.downcase]
        content_type = types[0]
      end

      if content_type
        if Image.accept_content_type?(content_type)
          klass = Image
        elsif Template.accept_content_type?(content_type)
          klass = Template
        elsif TextDocument.accept_content_type?(content_type)
          klass = TextDocument
        end
      elsif self == Document
        # no content_type means no file. Only TextDocuments can be created without files
        content_type = 'text/plain'
        klass = TextDocument
      end

      attrs['content_type'] = content_type

      if klass != self
        klass.with_scope(scope) { klass.o_new(attrs) }
      else
        klass.o_new(attrs)
      end
    end

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Document', :without => 'Image')
    end
  end # class << self

  def update_attributes(attributes)
    # Release content_type to nil before update, so that the execution is not influenced by existing file.
    attributes.stringify_keys!
    prop['content_type'] = nil if attributes['file'] || attributes['crop']
    super
  end

  # Create an attachment with a file in file system. Create a new version if file is updated.
  def file=(new_file)
    if version_file = super(new_file)
      prop['content_type'] ||= version_file.content_type
      prop['size'] = version.file.size
      prop['ext'] = set_extension(new_file)
      self.set_name_and_title(version_file)
      version_file
    end
  end

  # Get version title
  def title
    @title ||= version.title
  end

  # Set version title name
  def title=(t)
    version.title = t
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
  def filename
   version.attachment.filename
  end

  # Get the file path defined in attachment.
  def filepath(format=nil)
    version.attachment.filepath(format)
  end

  # Get the node's rootpath with the file's extention.
  def rootpath
    super + ".#{prop['ext']}"
  end

  protected

    def set_name_and_title(file)
      if base = self['name'] || version.title || file.original_filename
        if base =~ /(.*)\.(\w+)$/
          self['name'] = $1 if new_record?
        else
          self['name'] = base if new_record?
        end
        if version.title.to_s =~ /\A(.*)\.#{self.properties['ext']}$/i
          version.title = $1
        end
      end
    end

    # Make sure name is unique
    def node_before_validation
      get_unique_name_in_scope('ND%')
      super
    end

    def set_extension(new_file)
      extensions = Zena::TYPE_TO_EXT[prop['content_type']]
      if extensions && content_type != 'application/octet-stream' # use 'bin' extension only if we do not have any other ext.
        (prop['ext'] && extensions.include?(prop['ext'].downcase)) ? self.prop['ext'].downcase : extensions[0]
        #new_file.original_filename.split('.').last.downcase
      else
        # unknown content_type or 'application/octet-stream' , just keep the extension we have
        'bin'
      end
    end

end