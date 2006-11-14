require 'fileutils'
class DocFile < ActiveRecord::Base
  belongs_to :version
  before_save :save_file
  
  def file=(aFile)
    @file = aFile
    self[:content_type] = @file.content_type.chomp
    self[:size] = @file.stat.size
  end
  
  def read
    File.read(filepath)
  end

  def name
    path.split('/').last
  end
  
  private
  def save_file
    # make path
    make_path
    
    # save file
    raise StandardError, "File not set" unless @file
    p = filepath.split('/')
    p.pop
    p = p.join('/')
    unless File.exist?(p)
      FileUtils::mkpath(p)
    end
    File.open(filepath, "wb") { |f| f.syswrite(@file.read) }
    self[:size] = File.stat(filepath).size
  end
  
  def make_path
    file_name = version.item.name
    extension = file_name.split(".").last
    self[:path] = "/#{extension}/#{version_id}/#{file_name}"
  end
  
  def filepath
    "#{RAILS_ROOT}/data/#{RAILS_ENV}#{path}"
  end
end
