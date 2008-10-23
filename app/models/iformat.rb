class Iformat < ActiveRecord::Base
  before_validation :iformat_before_validation
  validate          :iformat_valid
  validates_uniqueness_of :name, :scope => :site_id
  after_save        :set_site_formats_date_and_expire_cache
  after_destroy     :set_site_formats_date_and_expire_cache
  SIZES   = ['keep', 'limit', 'force']
  GRAVITY = ['CenterGravity', 'NorthWestGravity', 'NorthGravity', 'NorthEastGravity', 'WestGravity', 'EastGravity', 'SouthWestGravity', 'SouthGravity', 'SouthEastGravity']
  
  class << self
    def [](fmt)
      Thread.current.visitor.site.iformats[fmt]
    end
    
    def list
      res = []
      Thread.current.visitor.site.iformats.merge(formats_for_site(visitor.site.id, false)).each do |k,v|
        next if k == :updated_at || k.nil?
        if v.kind_of?(Iformat)
          res << v
        else
          res << Iformat.new_from_default(k)
        end
      end
      res.sort do |a,b|
        if a.size == 'keep'
          b.size == 'keep' ? a[:name] <=> b[:name] : 1
        else
          (a.width * a.height) <=> (b.width * b.height)
        end
      end
    end
    
    def formats_for_site(site_id, as_hash = true)
      formats = ImageBuilder::DEFAULT_FORMATS.dup
        
      site_formats = {}
      last_update = nil

      self.find(:all, :conditions=>["site_id = ?", site_id]).each do |f|
        last_update  = f.updated_at if !last_update || f.updated_at > last_update
        if as_hash
          site_formats[f.name] = f.as_hash
        else
          site_formats[f.name] = f
        end
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
    {:name => self[:name], :size => size.to_sym, :width => width, :height => height, :gravity=>eval("Magick::#{gravity}")}
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
  
  def pseudo_id
    new_record? ? name : id
  end
  
  protected
    def iformat_valid
      if !visitor.is_admin?
        errors.add('base', 'you do not have the rights to do this')
        return false
      end
      
      if self[:name] == 'full'
        errors.add('name', "Cannot change 'full' format.")
        return false
      end
      
      errors.add('name', "invalid") if name.blank? || name =~ /[^a-zAZ]/
      if self.size != SIZES.index('keep')
        errors.add('width', "must be greater then 0") if width.to_i <= 0
        errors.add('height', "must be greater then 0") if height.to_i <= 0
      end
    end
    
    def iformat_before_validation
      self[:site_id] = visitor.site[:id]
      if self.size == SIZES.index('keep')
        self[:width] = nil 
        self[:height] = nil
      end
    end
    
    def set_site_formats_date_and_expire_cache
      Site.connection.execute "UPDATE sites SET formats_updated_at = (SELECT updated_at FROM iformats WHERE site_id = #{self[:site_id]} ORDER BY iformats.updated_at DESC LIMIT 1) WHERE id = #{self[:site_id]}"
      if self[:name] == 'full'
        # DO NOT CLEAR !
      else
        FileUtils.rmtree(File.join(SITES_ROOT, visitor.site.data_path, self[:name]))
        visitor.site.clear_cache(false)
      end
    end
end