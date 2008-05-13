class ImageFormat < ActiveRecord::Base
  before_validation :image_format_before_validation
  validate          :image_format_valid
  validates_uniqueness_of :name, :scope => :site_id
  after_save        :set_site_formats_date
  after_destroy     :set_site_formats_date
  SIZES   = ['keep', 'limit', 'force']
  GRAVITY = ['CenterGravity', 'NorthWestGravity', 'NorthGravity', 'NorthEastGravity', 'WestGravity', 'EastGravity', 'SouthWestGravity', 'SouthGravity', 'SouthEastGravity']
  
  class << self
    def [](fmt)
      Thread.current.visitor.site.image_formats[fmt]
    end
    
    def formats_for_site(site_id)
      formats = ImageBuilder::DEFAULT_FORMATS.dup
      site_formats = {}
      last_update = nil

      self.find(:all, :conditions=>["site_id = ?", site_id]).each do |f|
        last_update  = f.updated_at if !last_update || f.updated_at > last_update
        site_formats[f.name] = f.as_hash
      end
      
      formats.merge!(site_formats)
      formats[:updated_at] = last_update
      formats
    end
    
    def new_from_default(key)
      return nil unless default = ImageBuilder::DEFAULT_FORMATS[key]
      obj = self.new
      default.each do |k,v|
        obj.send("#{k}=", v.to_s)
      end
      obj
    end
  end
  
  # :size=>:force, :width=>280, :height=>120, :gravity=>Magick::NorthGravity  
  def as_hash
    {:size => size.to_sym, :width => width, :height => height, :gravity=>eval("Magick::#{gravity}")}
  end
  
  def size
    SIZES[self[:size].to_i]
  end
  
  def size=(str)
    self[:size] = SIZES.index(str)
  end
  
  def gravity
    GRAVITY[self[:gravity].to_i]
  end
  
  def gravity=(str)
    self[:gravity] = GRAVITY.index(str)
  end 
  
  protected
    def image_format_valid
      if !visitor.is_admin?
        errors.add('base', 'you do not have the rights to do this')
        return false
      end
      
      errors.add('name', "invalid") if name.blank? || name =~ /[^a-zAZ]/
      if self.size != 'keep'
        errors.add('width', "must be greater then 0") if width.to_i <= 0
        errors.add('height', "must be greater then 0") if height.to_i <= 0
      end
    end
    
    def image_format_before_validation
      self[:site_id] = visitor.site[:id]
      if self.size == 'keep'
        self[:width] = nil 
        self[:height] = nil
      end
    end
    
    def set_site_formats_date
      Site.connection.execute "UPDATE sites SET formats_updated_at = (SELECT updated_at FROM image_formats WHERE site_id = #{self[:site_id]} ORDER BY image_formats.updated_at DESC LIMIT 1) WHERE id = #{self[:site_id]}"
    end
end