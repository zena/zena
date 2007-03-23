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
class Document < Page
  before_validation :document_before_validation
  
  class << self
    def parent_class
      Node
    end
    
    alias o_new new
    
    # Return a new Document or a sub-class of Document depending on the file's content type. Returns a TextDocument if there is no file.
    def new(hash)
      scope = self.scoped_methods[0] || {}
      klass = self
      if hash[:c_file]
        content_type = hash[:c_file].content_type
      elsif hash[:c_content_type]
        content_type = hash[:c_content_type]
      elsif hash[:name] =~ /^.*\.(\w+)$/ && types = EXT_TO_TYPE[$1]
        content_type = types[0]
      else
        content_type = 'text/plain'
      end
      if Image.accept_content_type?(content_type)
        klass = Image
      elsif Template.accept_content_type?(content_type)
        if hash[:parent_id] && Node.find(hash[:parent_id]).kind_of?(Skin)
          klass = Template
        else
          klass = Skin
        end
      elsif TextDocument.accept_content_type?(content_type)
        klass = TextDocument
      else
        klass = Document
      end
      klass.with_scope(scope) { klass.o_new(hash) }
    end
  end
  
  ## Set content file
  #def c_file=(file)
  #  # make sure changes are saved in a redaction
  #  edit_content!
  #  
  #  content.file = @file
  #end
  
  # Return true if the document is an image.
  def image?
    kind_of?(Image)
  end
  
  # Return the document's filename using the name and the file extension.
  def filename
    "#{name}.#{version.content.ext}"
  end
  
  # Display an image tag to show the document inline. See DocumentContent and ImageContent for details.
  def img_tag(format=nil, opts={})
    version.content.img_tag(format, opts)
  end
  
  private
  
  # Set name from filename
  def document_before_validation
    content = version.content
    if new_record?
      if self[:name] && self[:name] != ""
        # name set
        base = self[:name]
      elsif file = content.instance_variable_get(:@file)
        # set with filename
        base = file.original_filename
      else
        # set with title
        base = version.title
      end
      if base =~ /\./
        self[:name] = base.split('.')[0..-2].join('.')
        ext  = base.split('.').last
      end
      content[:name] = self[:name]
      content.ext    = ext
    else
      # when cannot use 'old' here as this record is not secured when spreading inheritance
      if self[:name] != self.class.find(self[:id])[:name] && self[:name] && self[:name] != ''
        # update all content names :
        versions.each do |v|
          if v[:id] == @version[:id]
            v = @version # make sure modifications are made to our loaded version/content
          else
            v.node = self # preload so the relation to 'self' is kept
          end
          content = v.content
          content.name = self[:name]
          content.save
        end
      end
    end
  end
  
  # Sweep cached data for the document
  # TODO: test 
  def sweep_cache
    super
    # Remove cached data from the public directory.
    versions.each do |v|
      next if v[:content_id]
      FileUtils::rmtree(File.dirname(v.content.cachepath))
    end
  end

  # This is a callback from acts_as_multiversioned
  def version_class
    DocumentVersion
  end
end