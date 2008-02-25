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
  
  zafu_readable      :filename
  
  before_validation :document_before_validation
  
  class << self
    
    def version_class
      DocumentVersion
    end
    
    alias o_new new
    
    # Return a new Document or a sub-class of Document depending on the file's content type. Returns a TextDocument if there is no file.
    def new(hash = {})
      scope = self.scoped_methods[0] || {}
      klass = self
      hash  = hash.stringify_keys
      if file = hash['c_file'] && file.respond_to?(:content_type)
        content_type = file.content_type
      elsif hash['c_content_type']
        content_type = hash['c_content_type']
      elsif hash['name'] =~ /^.*\.(\w+)$/ && types = EXT_TO_TYPE[$1]
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
      
      hash['c_content_type'] = content_type
      
      if klass != self
        klass.with_scope(scope) { klass.o_new(hash) }
      else
        klass.o_new(hash)
      end
    end
  end
  
  # This looks really silly and is very anoying.
  #def name=(str)
  #  super
  #  if self[:name]
  #    version.content[:name] = self[:name].sub(/\.*$/,'') # remove trailing dots
  #  end
  #end

  # Filter attributes before assignement.
  # Set name of new record and content extension based on file.
  def filter_attributes(attributes)
    if attributes['name']
      # set through name
      base = attributes['name']
    elsif file = attributes['c_file']
      # set with filename
      base = file.original_filename
    end
    
    if base
      if base =~ /(.*)\.(\w+)$/
        attributes['name']    = $1 if new_record?
        attributes['c_ext'] ||= $2
      else
        attributes['name']    = base if new_record?
      end
    end
    
    attributes
  end
  
  # FIXME: why do we need this ?
  def attributes=(attributes)
    if content_type = attributes.delete('c_content_type')
      # make sure 'content_type' is set before the rest.
      version.content.content_type = content_type
    end
    
    super(attributes)
  end
  
  # Return true if the document is an image.
  def image?
    kind_of?(Image)
  end
  
  # Return the document's public filename using the name and the file extension.
  def filename
    "#{name}.#{version.content.ext}"
  end
  
  def rootpath
    super + ".#{version.content.ext}"
  end
  
  private
  
    # Set name from filename
    def document_before_validation
      content = version.content
      unless new_record?
        # we cannot use 'old' here as this record is not secured when spreading inheritance
        if self[:name] != self.class.find(self[:id])[:name] && self[:name] && self[:name] != ''
          # FIXME: name is not important (just used to find file in case db crash: do not sync.)
          # update all content names :
          versions.each do |v|
            if v[:id] == @version[:id]
              v = @version # make sure modifications are made to our loaded version/content
            else
              v.node = self # preload so the relation to 'self' is kept
            end
            content = v.content
            content.name = self[:name].sub(/\.*$/,'') # remove trailing dots
            content.save
          end
        end
      end
    end
end