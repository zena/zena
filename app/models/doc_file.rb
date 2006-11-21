require 'fileutils'
class DocFile < ActiveRecord::Base
  belongs_to :version
  validate :docfile_valid
  before_save :save_file
  
  def file=(aFile)
    @file = aFile
    self[:content_type] = @file.content_type.chomp
    self[:size] = @file.stat.size
  end
  
  def size=(s)
    raise StandardError, "Size cannot be set. It is defined by the file size."
  end
  
  def size
    self[:size] ||= File.exist?(filepath) ? File.stat(filepath).size : nil
  end
  
  def read
    if self[:version_id] && !new_record? && File.exist?(filepath)
      File.read(filepath)
    elsif @file
      @file.read
    else
      raise IOError, "File not found"
    end
  end
  
  # used by DocumentController when sending files
  def filename
    version.item.name
  end
  
  private
  def docfile_valid
    errors.add('version_id', 'version must exist') unless self.version
    errors.add('base', 'file not set') unless @file || !new_record?
  end
  
  def save_file
    if @file
      p = File.join(*filepath.split('/')[0..-2])
      unless File.exist?(p)
        FileUtils::mkpath(p)
      end
      File.open(filepath, "wb") { |f| f.syswrite(@file.read) }
      self[:size] = File.stat(filepath).size
    end
  end
  
  def filepath
    unless path && path != ""
      self[:path] = make_path
    end
    "#{RAILS_ROOT}/data/#{RAILS_ENV}#{path}"
  end
  
  def make_path
    raise StandardError, "Path not set yet, version must be saved first" unless self[:version_id] 
    extension = filename.split(".").last
    self[:path] = "/#{extension}/#{version_id}/#{filename}"
  end
  
end
