require 'test_helper'

class Zena::Use::ImageBuilderTest < Zena::Unit::TestCase

  # Dummy tests
  if Zena::Use::ImageBuilder.dummy?
    def test_dummy
      img = nil
      assert_nothing_raised { img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path, :width=>100, :height=>30) }
      assert img.dummy?, 'Image is a dummy'
      assert_nil img.read
      assert_equal 100, img.width
      assert_equal 30, img.height
    end

    def test_render_img
      img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path, :width=>100, :height=>30)
      assert_raise(IOError) { img.render_img }
    end

    def test_rows_0
      img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path)
      assert_nil img.width
      assert_nil img.height
    end
  else
    def test_dummy
      img = nil
      assert_nothing_raised { img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path, :width=>100, :height=>30) }
      assert ! Zena::Use::ImageBuilder.dummy?, 'Image is not a dummy'
      assert_nothing_raised { img.render_img }
      assert img.read
      assert_equal 100, img.width
      assert_equal 30, img.height
    end

    def test_render_without_img
      img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
      assert ! Zena::Use::ImageBuilder.dummy?, 'Class is not a dummy'
      assert img.dummy?, 'Image is a dummy'
      assert_raise(IOError) { img.render_img }
      assert_nil img.read
    end

    def test_render_img
      img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path, :width=>100, :height=>30)
      assert_nothing_raised { img.render_img }
    end

    def test_write_sepia
      img = Zena::Use::ImageBuilder.new(:path=>uploaded_jpg('bird.jpg').path)
      img.transform!(:size=>:limit, :width=>280, :ratio=>2/3.0, :post=>Proc.new {|img| img.sepiatone(Magick::MaxRGB * 0.8)})
      assert !File.exist?("#{SITES_ROOT}/test.host/sepia.jpg"), "File does not exist"
      assert_nothing_raised { img.write("#{SITES_ROOT}/test.host/sepia.jpg")}
      assert File.exist?("#{SITES_ROOT}/test.host/sepia.jpg"), "File saved ok"
      FileUtils.rm("#{SITES_ROOT}/test.host/sepia.jpg")
    end

    def test_png
      path = "#{Zena::ROOT}/public/images/ext/pdf.png"
      img = Zena::Use::ImageBuilder.new(:path=>path, :width=>30, :height=>30)
      img.transform!(:size=>:force, :width=>70,  :height=>79)
      assert_nothing_raised { data = img.read }
    end

    def test_format
      path = "#{Zena::ROOT}/public/images/ext/pdf.png"
      img = Zena::Use::ImageBuilder.new(:path=>path, :width=>30, :height=>30)
      img.format = 'jpg'
      new_img = img.render_img
      assert_kind_of Magick::ImageList, new_img
      assert_equal 'JPG', new_img.format
    end

    def test_limit_size
      path = "#{Zena::ROOT}/test/fixtures/files/bird.jpg"
      img = Zena::Use::ImageBuilder.new(:path=>path, :width=>30, :height=>30)
      assert_equal 56243, File.stat(path).size
      img.max_filesize = 40000
      new_img = img.render_img
      assert_kind_of Magick::ImageList, new_img
      f = Tempfile.new('test_limit')
      img.write(f.path)
      assert File.stat(f.path).size <= 40000 * 1.1 # approx reduction
    end
  end

  def test_image_content_type
    assert Zena::Use::ImageBuilder.image_content_type?('image/jpeg'), "jpeg is an image"
    assert Zena::Use::ImageBuilder.image_content_type?('image/png'), "png is an image"
    assert ! Zena::Use::ImageBuilder.image_content_type?('application/pdf'), "pdf is not an image"
  end

  def test_resize
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.resize!(0.5)
    assert_equal 50, img.width
    assert_equal 15, img.height
  end

  def test_crop_min
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.crop_min!(80, 70)
    assert_equal 80, img.width
    assert_equal 30, img.height
  end

  def test_crop
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.crop!(5, 10, 80, 70)
    assert_equal 80, img.width
    assert_equal 20, img.height
  end

  def test_set_background
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.set_background!(Magick::MaxRGB,120,15)
    assert_equal 120, img.width
    assert_equal 30, img.height
  end

  def test_transform_limit
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.transform!(:size=>:limit, :width=>80, :height=>60)
    assert_equal 80, img.width
    assert_equal 24, img.height
  end

  def test_transform_force
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.transform!(:size=>:force, :width=>80, :height=>60)
    assert_equal 80, img.width
    assert_equal 60, img.height
  end

  def test_transform_force_no_crop
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.transform!(:size=>:force_no_crop, :width=>80, :height=>60)
    assert_equal 80, img.width
    assert_equal 60, img.height
  end

  def test_transform_ratio
    img = Zena::Use::ImageBuilder.new(:width=>100, :height=>30)
    img.transform!(:size=>:force, :height=>30, :ratio=>3.0/4)
    assert_equal 30, img.height
    assert_equal 40, img.width
  end

  def test_transform_ratio_width
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:size=>:force, :width=>40, :ratio=>3.0/4.0)
    assert_equal 30, img.height
    assert_equal 40, img.width
  end

  def test_transform_scale
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:size=>:force, :scale=>0.5)
    assert_equal 15, img.width
    assert_equal 50, img.height
  end

  def test_transform_scale_up
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:size=>:force, :scale=>2.0)
    assert_equal 60, img.width
    assert_equal 200, img.height
  end

  def test_transform_scale_up_no_size
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:scale=>2.0)
    assert_equal 60, img.width
    assert_equal 200, img.height
    img.transform!(:scale=>0.5)
    assert_equal 30, img.width
    assert_equal 100, img.height
    img.transform!(:size=>:limit, :scale=>2.0)
    assert_equal 60, img.width
    assert_equal 200, img.height
  end

  def test_transform_limit_with_ratio
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:size=>:limit, :height=>50, :ratio=>2.0/1.0)
    assert_equal 15, img.width
    assert_equal 50, img.height
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:size=>:limit, :height=>200, :ratio=>4.0/1.0)
    assert_equal 30, img.width
    assert_equal 100, img.height
    img = Zena::Use::ImageBuilder.new(:width=>30, :height=>100)
    img.transform!(:height=>50, :ratio=>1.0/3.0)
    assert_equal 15, img.width
    assert_equal 50, img.height
  end

  def test_exif
    path = "#{Zena::ROOT}/test/fixtures/files/exif_sample.jpg"
    img = Zena::Use::ImageBuilder.new(:path=>path)
    exif = img.exif

    assert exif['DateTime']
    assert_equal 'SANYO Electric Co.,Ltd.', exif['Make']
  end

  def test_parse_dates_in_exif
    path = "#{Zena::ROOT}/test/fixtures/files/exif_sample.jpg"
    img = Zena::Use::ImageBuilder.new(:path=>path)
    assert_equal "1998:01:01 00:00:00", img.exif['DateTime']
    assert_equal Time.parse("1998-01-01 00:00:00"), img.exif.date_time
  end
end
