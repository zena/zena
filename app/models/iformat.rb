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
          b.size == 0 ? a[:name] <=> b[:name] : 1
        elsif b.size == 'keep'
          -1
        else
          sz = (a.width.to_f * a.height.to_f) <=> (b.width.to_f * b.height.to_f)
          if sz == 0
            a[:name] <=> b[:name]
          else
            sz
          end
        end
      end
    end

    def formats_for_site(site_id, as_hash = true)
      formats = ::ImageBuilder::DEFAULT_FORMATS.dup

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
        next if k == :hash_id
        obj.send("#{k}=", v.to_s)
      end
      obj
    end
  end

  # :size=>:force, :width=>280, :height=>120, :gravity=>Magick::NorthGravity
  def as_hash
    if self[:popup]
      if self[:popup] =~ /^(\w+?)\s*\((.*)\)/
        popup = {:name => $1}
        show = $2.split(',').map(&:strip)
        options = {}
        popup[:show] = show.map do |k|
          if k == 'link'
            options['v_title'] = 'link'
            'v_title'
          else
            k
          end
        end
        popup[:options] = options
      elsif self[:popup] =~ /^(\w+?)\s*(\{.*\})\s*$/
        popup = {:name => $1}
        options = JSON.load($2) rescue {}
        unless popup[:show] = options.delete('show')
          popup[:show] = options.keys.sort do |a,b|
            # keep sort order
            self[:popup].index(a) <=> self[:popup].index(b)
          end
          popup[:options] = {}
          options.each do |k,v|
            next if v == true
            popup[:options][k] = v
          end
        end
      else
        popup = {
          :name    => self[:popup],
          :options => {'v_title' => 'link'},
          :show    => ['navigation','v_title','v_summary']
        }
      end
    else
      popup = nil
    end

    h = {
      :name    => self[:name],
      :size    => size.to_sym,
      :width   => width,
      :height  => height,
      :gravity => eval("Magick::#{gravity}"),
    }
    h.merge!(:hash_id => ImageBuilder.hash_id(h))
    h.merge!(:popup => popup) if popup
    h
  end

  # This is a unique identifier used to cache images with format:
  # image30_pv.jpg#{node.updated_at.to_i + format.hash_id}
  def hash_id
    ImageBuilder.hash_id(self.as_hash)
  end

  def size
    SIZES[self[:size].to_i]
  end

  def size=(str)
    self[:size] = SIZES.index(str.to_s)
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
        errors.add('base', 'You do not have the rights to do this.')
        return false
      end

      if self[:name] == 'full'
        errors.add('name', "Cannot change 'full' format.")
        return false
      end

      errors.add('name', "invalid") if name.blank? || name =~ /[^a-zA-Z]/
      if self.size != SIZES.index('keep')
        errors.add('width', "must be greater then 0") if width.to_i <= 0
        errors.add('height', "must be greater then 0") if height.to_i <= 0
      end
    end

    def iformat_before_validation
      self[:site_id] = visitor.site[:id]
      self[:popup] = nil if self[:popup].blank?
      if self.size == SIZES.index('keep')
        self[:width] = nil
        self[:height] = nil
      end
    end

    def set_site_formats_date_and_expire_cache
      visitor.site.iformats_updated!
      if self[:name] == 'full'
        # ORIGINAL DATA: DO NOT CLEAR !
      else
        FileUtils.rmtree(File.join(SITES_ROOT, visitor.site.data_path, self[:name]))
        visitor.site.clear_cache(false)
      end
    end
end