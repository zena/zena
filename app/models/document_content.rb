require 'fileutils'
class DocumentContent < ActiveRecord::Base
  belongs_to :version
  validate :valid_file
  validates_presence_of :ext
  validates_presence_of :name
  before_save :set_with_file
  after_save :save_file
  after_destroy :destroy_file
  
  # format is ignored here
  def img_tag(format=nil)
    ext = self[:ext]
    unless File.exist?("#{RAILS_ROOT}/public/images/ext/#{ext}.png")
      ext = 'other'
    end
    unless format
      # img_tag from extension
      "<img src='/images/ext/#{ext}.png' width='32' height='32' class='icon'/>"
    else
      img = ImageBuilder.new(:path=>"#{RAILS_ROOT}/public/images/ext/#{ext}.png", :width=>32, :height=>32)
      img.transform!(format)
      path = "#{RAILS_ROOT}/public/images/ext/"
      filename = "#{ext}-#{format}.png"
      unless File.exist?(File.join(path,filename))
        # make new image with the format
        unless File.exist?(path)
          FileUtils::mkpath(path)
        end
        if img.dummy?
          File.cp("#{RAILS_ROOT}/public/images/ext/#{ext}.png", "#{RAILS_ROOT}/public/images/ext/#{ext}-#{format}.png")
        else
          File.open(File.join(path, filename), "wb") { |f| f.syswrite(img.read) }
        end
      end
      "<img src='/images/ext/#{filename}' width='#{img.width}' height='#{img.height}' class='#{format}'/>"
    end
  end
  
  def file=(aFile)
    @file = aFile
    self[:content_type] = @file.content_type.chomp
    self[:size] = @file.stat.size
  end
  
  def size=(s)
    raise StandardError, "Size cannot be set. It is defined by the file size."
  end
  
  def read
    if !new_record? && File.exist?(filepath)
      File.read(filepath)
    elsif @img
      @img.read
    elsif @file
      @file.read
    else
      raise IOError, "File not found"
    end
  end
  
  def filename
    "#{name}.#{ext}"
  end
  
  def path
    raise StandardError, "path cannot be called before record is saved" unless !new_record?
    "/#{ext}/#{self[:id]}/#{filename}"
  end
  
  def filepath
    "#{RAILS_ROOT}/data/#{RAILS_ENV}#{path}"
  end
  
  private
  
  def valid_file
    errors.add('base', 'file not set') unless !new_record? || @file || @img
    if @file && kind_of?(ImageVersion) && !Image.image_content_type?(@file.content_type)
      errors.add('file', 'must be an image')
    end
  end
  
  # def can_update_file
  #   if @file && (self[:file_ref] == self[:id]) && (Version.find_all_by_file_ref(self[:id]).size > 1)
  #     errors.add('file', 'cannot be changed (used by other versions)')
  #   end
  # end
  # 
  # def create_doc_file
  #   if @file
  #     # new document or new edition with a new file
  #     self[:file_ref] = self[:id]
  #     DocumentVersion.connection.execute "UPDATE versions SET file_ref=id WHERE id=#{id}"
  #     file_class.create(:version_id=>self[:id], :file=>@file, :ext=>@ext)
  #   end
  # end
  # 
  # def update_file_ref
  #   if @file
  #     # redaction with a new file
  #     if self[:file_ref] == self[:id]
  #       # our own file changed
  #       doc_file.file = @file
  #       doc_file.ext  = @ext
  #       doc_file.save
  #     else
  #       self[:file_ref] = self[:id]
  #       file_class.create(:version_id=>self[:id], :file=>@file, :ext=>@ext)
  #     end
  #   end
  # end
  
  def set_with_file
    if @img || @file
      # set extension
      ext  = self[:ext] || @file.original_filename.split('.').last
      # is this extension valid ?
      extensions = TYPE_TO_EXT[self[:content_type]]
      if extensions
        self[:ext] = extensions.include?(ext) ? ext : extensions[0]
      else
        self[:ext] = "???"
      end
      if @img
        self[:size] = @img.read.size
      else
        self[:size] = @file.stat.size
      end
      true
    end
  end
  
  def save_file
    p = File.join(*filepath.split('/')[0..-2])
    unless File.exist?(p)
      FileUtils::mkpath(p)
    end
    File.open(filepath, "wb") { |f| f.syswrite((@img || @file).read) }
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
