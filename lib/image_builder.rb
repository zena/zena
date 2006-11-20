begin
  require 'rmagick'
rescue LoadError
  puts "ImageMagick not found. Using dummy."
  # Create a dummy magick module
  module Magick
    CenterGravity = OverCompositeOp = MaxRGB = nil
    class << self
    end
    class ZenaDummy
      def initialize(*a)
      end
      def dummy?
        true
      end
      def method_missing(meth, *args)
        # do nothing
      end
    end
    class Image < ZenaDummy
    end
    class ImageList < ZenaDummy
    end
  end
end

class ImageBuilder
  
  def initialize(h)
    params = {:height=>nil, :width=>nil, :path=>nil, :file=>nil, :actions=>[]}.merge(h)

    params.each_pair do |k,v|
      case k
      when :height
        @height = v if v
      when :width
        @width = v if v
      when :path
        @path = v if v
      when :file
        @file = v if v
      when :actions
        if v.kind_of?(Array)
          @actions = v
        else
          raise StandardError, "Bad actions format"
        end
      else
        raise StandardError, "Bad parameter (#{k})"
      end
    end
  end
  
  def dummy?
    Magick.const_defined?(:ZenaDummy)
  end
  
  def read
    return nil if dummy? || (!@path && !@img && !@file)
    render_img
    @img.to_blob
  end
  
  def rows
    return nil unless @height || !dummy?
    (@height ||= render_img.rows).to_i
  end
  
  def columns
    return nil unless @width || !dummy?
    (@width ||= render_img.columns).to_i
  end
  
  alias height rows
  alias width columns
  
  def resize!(s)
    @width  *= s
    @height *= s
    @actions << "@img.resize!(#{s})"
  end
  
  def crop_min!(w,h)
    @width  = [@width ,w].min
    @height = [@height,h].min
    @actions << "@img.crop!(Magick::CenterGravity,[#{w},@img.columns].min,[#{h},@img.rows].min)"
  end
  
  def set_background!(opacity,w,h)
    @width  = [@width ,w].max
    @height = [@height,h].max
    @actions << "bg = Magick::Image.new(#{w},#{h})"
    @actions << "bg.opacity = #{opacity}"
    @actions << "@img = bg.composite(@img, Magick::CenterGravity, Magick::OverCompositeOp)"
  end
  
  def transform!(tformat)
    if tformat.kind_of?(String)
      tformat = IMAGEBUILDER_FORMAT[tformat] || {}
    end
    format = { :size=>:limit, :ratio=>2.0/3.0 }.merge(tformat)
    
    if format[:size] == :keep
      h,w = @height, @width
    else
      h,w = format[:height], format[:width]
    end
    if format[:scale]
      if h || w
        # scale is a pre-zoom before crop
        scale = format[:scale]
      else
        # we resize to scale
        h,w = @height*format[:scale], @width*format[:scale]
        # but we do not zoom
        scale = 1.0
        # ignore ':size' format if not height nor width was given
        format[:size] = :force
      end
    else
      scale = 1.0
    end
    if format[:ratio] && h && !w
      w = h / format[:ratio]
    elsif format[:ratio] && w && !h
      h = w * format[:ratio]
    end

    pw,ph = @width, @height
    raise StandardError, "image size or thumb size is null" if [w,h,pw,ph].include?(nil) || [w,h,pw,ph].min <= 0

    case format[:size]
    when :force
      crop_scale = [w.to_f/pw, h.to_f/ph].max
      resize!(crop_scale * scale)
      crop_min!(w, h)
    when :force_no_crop
      crop_scale = [w.to_f/pw, h.to_f/ph].min
      resize!(crop_scale * scale)
      crop_min!(w, h)
      set_background!(Magick::MaxRGB, w, h)
    when :limit
      crop_scale = [w.to_f/pw, h.to_f/ph].min
      resize!(crop_scale * scale) if crop_scale < 1
      crop_min!(w, h)
    when :keep
    end
    self
  end
  
  def render_img
    raise IOError, 'MagickDummy cannot render image' if dummy?
    unless @img
      if @file
        @img = Magick::ImageList.new
        @img.from_blob(@file.read)
      elsif @path
        @img = Magick::ImageList.new(@path)
      else
        raise IOError, 'Cannot render image without path or file'
      end
      if @actions
        @actions.each do |a|
          eval a
        end
      end
    end
    @img
  end
end

IMAGEBUILDER_FORMAT = {
  'tiny' => { :size=>:force, :width=>15,  :height=>20,  :scale=>1.25  },
  'mini' => { :size=>:force, :width=>40,  :ratio=>1                   },
  'pv'   => { :size=>:limit, :width=>80,  :height=>80                 },
  'med'  => { :size=>:limit, :width=>280, :ratio=>2/3.0               },
  'med2' => { :size=>:limit, :width=>280, :ratio=>2/3.0, :scale=>1.25 },
  'std'  => { :size=>:limit, :width=>600, :ratio=>2/3.0               },
  'full' => { :size=>:keep                                            },
}
