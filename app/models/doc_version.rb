# This class stores version text for #Document. If a translation or new redaction of the text
# is created, both the new and the old #DocVersion refer to the same file (#DocFile)
class DocVersion < Version
  has_one :doc_file
  after_save :save_file
  validate_on_create :has_file
  
  # format is ignored here
  def img_tag(format=nil)
    unless format
      # img_tag from extension
      "<img src='/images/ext/#{item.ext}.png' width='15' height='20' class='tiny'/>"
    else
      img = ImageBuilder.new(:path=>"#{RAILS_ROOT}/public/images/ext/#{item.ext}.png", :width=>15, :height=>20)
      img.transform!(format)
      # let the browser resize
      "<img src='/images/ext/#{item.ext}.png' width='#{img.width}' height='#{img.height}' class='#{format}'/>"
    end
  end
  
  def file
    @docfile ||= DocFile.find(:first, :conditions=>['version_id = ?',file_ref])
  end
  
  def filesize; file.size; end
    
  def file_ref=(i)
    raise Zena::AccessViolation, "Version#{self.id}: tried to change 'file_ref'."
  end
  
  def file=(f)
    @file = f
  end
  
  def title
    if self[:title] && self[:title] != ""
      self[:title]
    else
      item.name.split('.')[0..-2].join('.')
    end
  end
  
  private
  def set_file_ref
    self[:file_ref] ||= self[:id]
  end
  
  def has_file
    errors.add('base', 'file not set') unless @file
  end
  
  def save_file
    unless file_ref
      self[:file_ref] = self[:id]
      DocVersion.connection.execute "UPDATE versions SET file_ref=id WHERE id=#{id}"
    end
    if @file
      info_class.create(:version_id=>file_ref, :file=>@file)
      # TODO check for errors on info_class create
    end
  end
  
  def info_class
    DocFile
  end
end
