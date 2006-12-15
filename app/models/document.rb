=begin rdoc
TODO: on name change make sure content name changes too...
=end
class Document < Page
  before_validation :set_name
  before_save       :update_content_name
  
  class << self
    def parent_class
      Item
    end
  end
  
  def c_file=(file)
    @file = file
    # we call 'method missing' to do normal file setting on content
    method_missing(:c_file=,file)
  end
  
  def image?
    kind_of?(Image)
  end
  
  def filename
    "#{name}.#{version.content.ext}"
  end
  
  def img_tag(format=nil)
    version.content.img_tag(format)
  end
  
  private
  
  # Set name from filename
  def set_name
    return true unless new_record?
    if self[:name] && self[:name] != ""
      base = self[:name]
    elsif @file
      base = @file.original_filename
    else
      errors.add('name', 'cannot be empty')
      return false
    end
    if base =~ /\./
      self[:name] = base.split('.')[0..-2].join('.')
      c_ext  = base.split('.').last
      c_name = self[:name]
    end
    return true
  end

  def update_content_name
    # when cannot use 'old' here as this record is not secured when spreading inheritance
    if !new_record? && (self[:name] != self.class.find(self[:id])[:name])
      # update all content names :
      versions.each do |v|
        content = v.content
        content.name = self[:name]
        content.save
      end
    end
  end
  # This is a callback from acts_as_multiversioned
  def version_class
    DocumentVersion
  end
end