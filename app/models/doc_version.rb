# This class stores version text for #Document. If a translation or new redaction of the text
# is created, both the new and the old #DocVersion refer to the same file (#DocFile)
class DocVersion < Version
  has_one :doc_file

  before_save :before_doc_version

  after_create :after_create_doc_version
  after_update :after_update_doc_version
  
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
    unless @docfile
      raise ActiveRecord::RecordNotFound, 'no DocFile found' unless 
        @docfile = DocFile.find(:first, :conditions=>['version_id = ?',file_ref])
    end
    @docfile
  end
  
  def filesize; file.size; end
    
  def file_ref=(i)
    raise Zena::AccessViolation, "'file_ref' cannot be changed 'file_ref'."
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
  
  def before_doc_version
    errors.add('base', 'file not set') unless @file || doc_file
  end
  
  def after_create_doc_version
    unless doc_file
      self[:file_ref] = self[:id]
      DocVersion.connection.execute "UPDATE versions SET file_ref=id WHERE id=#{id}"
      info_class.create(:version_id=>self[:id], :file=>@file)
    end
  end
  
  def after_update_doc_version
    if @file
      self[:file_ref] = self[:id]
      DocVersion.connection.execute "UPDATE versions SET file_ref=id WHERE id=#{id}"
      info_class.create(:version_id=>self[:id], :file=>@file)
    end
  end
  
  def info_class
    DocFile
  end
end
