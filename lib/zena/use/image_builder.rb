require 'tempfile'
require 'digest/sha1'
unless defined?(Magick)
  begin
    # this works on the deb box
    require 'RMagick'
  rescue LoadError
    begin
      # this works on my Mac
      require 'rmagick'
    rescue LoadError
      puts "ImageMagick not found. Using dummy."
      # Create a dummy magick module
      module Magick
        CenterGravity = OverCompositeOp = MaxRGB = NorthGravity = SouthGravity = nil
        class << self
        end
        class ZenaDummy
          def initialize(*a)
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
  end
end

module Zena
  module Use
    class ImageBuilder
      DEFAULT_FORMATS = {
        'tiny'  => { :name=>'tiny', :size=>:force, :width=>16,  :height=>16 , :gravity=>Magick::CenterGravity   },
        'tipop' => { :name=>'tipop', :size=>:force, :width=>16,  :height=>16 , :gravity=>Magick::CenterGravity,
          :popup => {
              :name    => 'std',
              :options => {'title' => 'link'},
              :show    => ['navigation','title','summary']
            }
        },
        'mini' =>   { :name=>'mini', :size=>:force, :width=>32,  :height=>32 , :gravity=>Magick::CenterGravity   },
        'square' => { :name=>'square', :size=>:limit, :width=>180, :height=>180, :gravity=>Magick::CenterGravity },
        'med'  =>   { :name=>'med',  :size=>:limit, :width=>280, :height=>186, :gravity=>Magick::CenterGravity   },
        'top'  =>   { :name=>'top',  :size=>:force, :width=>280, :height=>186, :gravity => Magick::NorthGravity  },
        'low'  =>   { :name=>'low',  :size=>:force, :width=>280, :height=>186, :gravity => Magick::SouthGravity  },
        'side' =>   { :name=>'side', :size=>:force, :width=>220, :height=>500, :gravity=>Magick::CenterGravity   },
        'std'  =>   { :name=>'std',  :size=>:limit, :width=>600, :height=>400, :gravity=>Magick::CenterGravity   },
        'pv'   =>   { :name=>'pv',   :size=>:force, :width=>70,  :height=>70 , :gravity=>Magick::CenterGravity   },
        'edit' =>   { :name=>'edit', :size=>:limit, :width=>400, :height=>400, :gravity=>Magick::CenterGravity   },
        'full' =>   { :name=>'full', :size=>:keep                            , :gravity=>Magick::CenterGravity   },
        nil    =>   { :name=>'full', :size=>:keep                            , :gravity=>Magick::CenterGravity   },
      }.freeze
      # 'sepia'=>   { :size=>:limit, :width=>280, :ratio=>2/3.0, :post=>Proc.new {|img| img.sepiatone(Magick::MaxRGB * 0.8)}},

      class << self
        def image_content_type?(content_type)
          content_type =~ /image/ && !content_type =~ /svg/
        end

        def dummy?
          Magick.const_defined?(:ZenaDummy)
        end

        def hash_id(format)
          Digest::SHA1.hexdigest("#{format[:name]}#{format[:size]}#{format[:width]}#{format[:height]}#{format[:gravity]}")[0..9].to_i(16)
        end

        DEFAULT_FORMATS.each do |k, v|
          v[:hash_id] = Zena::Use::ImageBuilder.hash_id(v)
          v.freeze
        end
      end

      def initialize(h)
        params = {:height=>nil, :width=>nil, :path=>nil, :file=>nil, :actions=>[]}.merge(h)

        params.each do |k,v|
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
        unless @width && @height || dummy?
          if @img = build_image_from_file_or_path
            @width  = @img.columns
            @height = @img.rows
          end
        end
      end

      def dummy?
        Zena::Use::ImageBuilder.dummy? || (!@path && !@img && !@file)
      end

      def read
        return nil if dummy?
        render_img
        @img.to_blob
      end

      def write(path)
        return false if dummy?
        render_img
        @img.write(path)
      end

      def rows
        return nil unless @height || !dummy?
        (@height ||= render_img.rows).round
      end

      def columns
        return nil unless @width || !dummy?
        (@width ||= render_img.columns).round
      end

      alias height rows
      alias width columns

      def resize!(s)
        # we do not zoom pixels
        return unless s < 1.0
        @img = nil # reset current rendered image
        @width  *= s
        @height *= s
        @actions << Proc.new {|img| img.resize!(s) }
      end

      def crop!(x,y,w,h)
        @img = nil # reset current rendered image
        @width  = [@width -x, w].min
        @height = [@height-y, h].min
        @actions << Proc.new {|img| img.crop!(x,y,[@img.columns-x, w].min,[@img.rows-y, h].min, true) }
      end

      def format=(fmt)
        return if dummy? || !Magick.formats[fmt.upcase] =~ /w/
        @actions << Proc.new {|img| img.format = fmt.upcase; img }
      end

      def format
        render_img.format
      end

      def exif
        @exif ||= ExifData.new(render_img.get_exif_by_entry)
      end

      def max_filesize=(size)
        @actions << Proc.new {|img| do_limit!(size) }
      end

      def do_limit!(size)
        return @img if @filesize <= size

        # Check real size
        tmp_path = Tempfile.new('tmp_img').path
        @img.write('jpeg:' + tmp_path)

        return @img if File.stat(tmp_path).size <= size

        # Change type to JPG and quality to 80
        if (@img.format == 'JPG' || @img.format == 'JPEG') && @img.quality > 80
          @img.write('jpeg:' + tmp_path) { self.quality = 80 }
        else
          @img.format = 'JPG'
          @img.write('jpeg:' + tmp_path) { self.quality = 80 }
        end
        ratio = File.stat(tmp_path).size.to_f / size

        return @img = Magick::ImageList.new(tmp_path) if ratio <= 1.0

        # Not enough ? Resize.
        ratio   = 1.0 / Math.sqrt(ratio)
        @width  *= ratio
        @height *= ratio
        @img.resize!(ratio)
        @img
      end

      def crop_min!(w,h,gravity=Magick::CenterGravity)
        @img = nil # reset current rendered image
        @width  = [@width ,w].min
        @height = [@height,h].min
        @actions << Proc.new {|img| img.crop!(gravity,[@img.columns,w].min,[@img.rows,h].min, true) }
      end

      def set_background!(opacity,w,h)
        @img = nil # reset current rendered image
        @width  = [@width ,w].max
        @height = [@height,h].max
        @actions << Proc.new do |img|
          bg = Magick::Image.new(w,h)
          bg.opacity = opacity
          bg.format = img.format
          img = bg.composite(img, Magick::CenterGravity, Magick::OverCompositeOp)
        end
      end

      # Transform into another format. If nil : do nothing.
      def transform!(tformat=nil)
        return self unless tformat
        @img = nil
        format = { :size=>:limit, :gravity=>Magick::CenterGravity }.merge(tformat)
        @pre, @post = format[:pre], format[:post]

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
        if [w,h,pw,ph].include?(nil) || [w,h,pw,ph].min <= 0
          # image size or thumb size is null (no image processing tool used, no idea on image size)
          if format[:size] == :keep
            @height, @width = nil, nil
          else
            @height, @width = h, w
          end
          return self
        end

        case format[:size]
        when :force
          crop_scale = [w.to_f/pw, h.to_f/ph].max
          if crop_scale > 1.0
            # we do not zoom. Fill with transparent background.
            crop_min!(w,h,format[:gravity])
            set_background!(Magick::MaxRGB, w, h)
          else
            resize!(crop_scale * scale)
            crop_min!(w, h,format[:gravity])
          end
        when :force_no_crop
          crop_scale = [w.to_f/pw, h.to_f/ph].min
          resize!(crop_scale * scale)
          crop_min!(w, h,format[:gravity])
          set_background!(Magick::MaxRGB, w, h)
        when :limit
          crop_scale = [w.to_f/pw, h.to_f/ph].min
          resize!(crop_scale * scale)
          crop_min!(w, h,format[:gravity])
        when :keep
        end
        self
      end

      def render_img
        raise IOError, 'MagickDummy cannot render image' if Zena::Use::ImageBuilder.dummy?
        unless @img
          unless @img = build_image_from_file_or_path
            raise IOError, 'Cannot render image without path or file'
          end
          if @pre
            @pre = [@pre].flatten
            @pre.each do |a|
              @img = a.call(@img)
            end
          end

          if @actions
            @actions.each do |a|
              @img = a.call(@img)
            end
          end

          if @post
            @post = [@post].flatten
            @post.each do |a|
              @img = a.call(@img)
            end
          end
        end
        @img
      end

      def build_image_from_file_or_path
        if @file || @path
          if @file.kind_of?(StringIO)
            img = Magick::ImageList.new
            @file.rewind
            img.from_blob(@file.read)
            @file.rewind
            @filesize = @file.size
            img
          else
            img = Magick::ImageList.new(@file ? @file.path : @path)
            @filesize = img.filesize
            img
          end
        end
      end
    end # ImageBuilder
  end # Use
end # Zena