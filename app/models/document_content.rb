require 'fileutils'
=begin rdoc
Used by Document and Image to store file data. See the documentation on these classes for more information.

=== Attributes

Provides the following attributes to Document and Image :

size::            file size
ext::             file extension 
content_type::    file content_type
=end
class DocumentContent < ActiveRecord::Base
  belongs_to            :version
  belongs_to            :site
  validate              :valid_file
  validates_presence_of :ext
  validates_presence_of :name
  validates_presence_of :version
  before_save           :content_before_save
  after_save            :content_after_save
  before_destroy        :destroy_file
  
  # protect access to size.
  def size=(s)
    raise StandardError, "Size cannot be set. It is defined by the file size."
  end
  
  def file=(aFile)
    @file = aFile
    return unless valid_file
    self[:content_type] = @file.content_type.chomp
    if @file.kind_of?(StringIO)
      self[:size] = @file.size
    else
      self[:size] = @file.stat.size
    end
    self.ext = self[:ext] || @file.original_filename.split('.').last
  end
  
  def ext=(theExt)
    if theExt && theExt != ''
      e = theExt
    else
      e = self[:ext]
    end
    # is this extension valid ?
    extensions = TYPE_TO_EXT[content_type]
    if extensions
      self[:ext] = extensions.include?(e) ? e : extensions[0]
    else
      self[:ext] = e
    end
  end
  
  def file(format=nil)
    if @file
      @file
    elsif File.exist?(filepath)
      File.new(filepath)
    else
      raise IOError, "File not found"
    end
  end
  
  def size(format=nil)
    return self[:size] if self[:size]
    if !new_record? && File.exist?(filepath)
      self[:size] = File.stat(filepath).size
      self.save
    end
    self[:size]
  end
  
  def filename(format=nil)
    "#{name}.#{ext}"
  end
  
  # Path to store the data. The path is build with the version id so we can do the security checks when uploading data.
  def filepath(format=nil)
    raise StandardError, "version not set" unless self[:version_id]
    "#{SITES_ROOT}#{site.data_path}/#{ext}/#{self[:version_id]}/#{filename(format)}"
  end
  
  private
  
  def valid_file
    return true if !new_record? || @file
    errors.add('file', "can't be blank")
    return false
  end
  
  def content_before_save
    
    self[:type] = self.class.to_s # make sure the type is set in case no sub-classes are loaded.
    if @file
      # destroy old file
      destroy_file unless new_record?
      # save new file
      make_file(filepath, @file)
    elsif !new_record? && (old = DocumentContent.find(self[:id])).name != self[:name]
      # TODO: test clear cached formated images
      # cache cleared with 'sweep_cache'
      # clear format images
      old.remove_format_images if old.respond_to?(:remove_format_images)
      FileUtils::mv(old.filepath, filepath)
    end
  end
  
  def content_after_save
    # we are done with this file
    @file = nil
  end
  
  def make_file(path, data)
    FileUtils::mkpath(File.dirname(path)) unless File.exist?(File.dirname(path))
    File.open(path, "wb") { |f| f.syswrite(data.read) }
  end
  
  def destroy_file
    # TODO: clear cache
    old_path = DocumentContent.find(self[:id]).filepath
    folder = File.join(*old_path.split('/')[0..-2])
    if File.exist?(folder)
      FileUtils::rmtree(folder)
    end
    # TODO: set content_id of versions whose content_id was self[:version_id]
  end
end
