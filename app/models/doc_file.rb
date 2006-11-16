require 'fileutils'
class DocFile < ActiveRecord::Base
  belongs_to :version
  validate :docfile_valid
  before_create :save_file
  
  def file=(aFile)
    puts "SET F"
    @file = aFile
    self[:content_type] = @file.content_type.chomp
    self[:size] = @file.stat.size
  end
  
  def size=(s)
    raise IOError
  end
  
  def size
    self[:size] ||= File.stat(filepath).size
  end
  
  def read
    if self[:version_id] && !new_record?
      File.read(filepath)
    elsif @file
      @file.read
    else
      nil
    end
  end
  
  private
  def docfile_valid
    errors.add('version_id', 'version must exist') unless self.version
    errors.add('base', 'file not set') unless @file || !new_record?
  end
  
  def save_file
    p = File.join(*filepath.split('/')[0..-2])
    unless File.exist?(p)
      FileUtils::mkfilepath(p)
    end
    File.open(filepath, "wb") { |f| f.syswrite(@file.read) }
    self[:size] = File.stat(filepath).size
  end
  
  def filepath
    unless path && path != ""
      raise StandardError, "Path not set yet, version must be saved first" unless self[:version_id] 
      file_name = version.item.name
      extension = file_name.split(".").last
      self[:path] = "/#{extension}/#{version_id}/#{file_name}"
    end
    "#{RAILS_ROOT}/data/#{RAILS_ENV}#{path}"
  end
end
