require 'fileutils'
class DocFile < ActiveRecord::Base
  belongs_to :version
  validate :docfile_valid
  before_save :save_file
  after_destroy :destroy_file
  
  def file=(aFile)
    @data = aFile
    self[:content_type] = @data.content_type.chomp
    self[:size] = @data.stat.size
  end
  
  def size=(s)
    raise StandardError, "Size cannot be set. It is defined by the file size."
  end
  
  def size
    unless self[:size]
      if self[:version_id] && File.exist?(filepath)
        self[:size] = File.stat(filepath).size
      end
    end
    self[:size]
  end
  
  def read
    if self[:version_id] && !new_record? && File.exist?(filepath)
      File.read(filepath)
    elsif @data
      @data.read
    else
      raise IOError, "File not found"
    end
  end
  
  # used by DocumentController when sending files
  def filename
    version.item.name
  end
  
  protected
  def filepath
    unless path && path != ""
      self[:path] = make_path
    end
    "#{RAILS_ROOT}/data/#{RAILS_ENV}#{path}"
  end
  
  private
  def docfile_valid
    errors.add('version_id', 'version must exist') unless self.version
    errors.add('base', 'file not set') unless @data || !new_record?
  end
  
  def save_file
    if @data
      p = File.join(*filepath.split('/')[0..-2])
      unless File.exist?(p)
        FileUtils::mkpath(p)
      end
      File.open(filepath, "wb") { |f| f.syswrite(@data.read) }
      self[:size] = File.stat(filepath).size
    end
  end

  def make_path
    raise StandardError, "Path not set yet, version must be saved first" unless self[:version_id] 
    extension = filename.split(".").last
    self[:path] = "/#{extension}/#{version_id}/#{filename}"
  end
  
  def destroy_file
    # TODO: clear cache
    if File.exist?(filepath)
      FileUtils::rm(filepath)
      folder = File.join(*filepath.split('/')[0..-2])
      if Dir.entries(folder).reject!{|e| (e=='.' || e=='..')} == []
        FileUtils::rmdir(folder)
      end
    end
  end
end
