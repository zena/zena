require File.dirname(__FILE__) + '/../test_helper'

class ImageFormatTest < ZenaTestUnit
  
  def setup
    super
    $image_formats = nil # also works without this, but the tests are more reliable with it
  end
  
  def test_default_format
    login(:tiger)
    assert_equal ({:width=>70, :height=>79, :size=>:force}), ImageFormat['pv']
  end
  
  def test_redefined_format
    login(:tiger)
    fmt = ImageFormat['std']
    assert_not_equal ImageBuilder::DEFAULT_FORMATS['std'], fmt
    assert_equal ({:width=>650, :height=>420, :gravity=>Magick::CenterGravity, :size=>:limit}), fmt
  end
  
  def test_other_site
    login(:whale)
    assert_equal ImageBuilder::DEFAULT_FORMATS['std'], ImageFormat['std']
  end
  
  def test_defined_format
    login(:lion)
    assert_nil ImageFormat['header']
    login(:whale)
    assert_equal ({:gravity=>Magick::NorthGravity, :width=>688, :size=>:force, :height=>178}), ImageFormat['header']
  end
  
  def test_mem_cached
    login(:whale)
    assert_equal 688, ImageFormat['header'][:width]
    ImageFormat.connection.execute "UPDATE image_formats SET width = 500 WHERE id = #{image_formats_id(:header)}"
    assert_equal 688, ImageFormat['header'][:width]
    $image_formats = nil
    assert_equal 688, ImageFormat['header'][:width]
  end
  
  def test_update_expire_mem_cache
    login(:tiger)
    assert_equal 650, ImageFormat['std'][:width]
    assert_equal '2008-05-01', $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = ImageFormat['std']
    assert_equal fmt1.object_id, ImageFormat['std'].object_id, "In cache"
    
    # Update format
    assert ImageFormat.update(image_formats_id(:redifined_std), :width => 700)
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:tiger) # flush visitor (new web query)
    assert_equal now, visitor.site[:formats_updated_at].strftime('%Y-%m-%d'), "Site's formats update date changed"
    
    # format hasn't change in memory yet
    assert_equal 650, $image_formats[sites_id(:zena)]['std'][:width], "Mem cached version not changed"
    
    fmt2 = ImageFormat['std'] # updates cache
    
    assert_equal 700, fmt2[:width], "Updated value"
    assert_equal now, $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, ImageFormat['std'].object_id, "In cache"
  end
  
  def test_destroy_expire_mem_cache
    login(:tiger)
    assert_equal 650, ImageFormat['std'][:width]
    assert_equal '2008-05-01', $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = ImageFormat['std']
    assert_equal fmt1.object_id, ImageFormat['std'].object_id, "In cache"
    
    # Destroy format
    assert ImageFormat.destroy(image_formats_id(:redifined_std))
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:tiger) # flush visitor (new web query)
    assert_nil visitor.site[:formats_updated_at], "Site's formats update date is NULL"
    
    # format hasn't change in memory yet
    assert_equal 650, $image_formats[sites_id(:zena)]['std'][:width], "Mem cached version not changed"
    
    fmt2 = ImageFormat['std'] # updates cache
    
    assert_equal 600, fmt2[:width], "Default value"
    assert_nil $image_formats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, ImageFormat['std'].object_id, "In cache"
  end
  
  def test_create_first
    login(:tiger)
    assert ImageFormat.destroy(image_formats_id(:redifined_std))
    fmt = ImageFormat['std']
    assert_nil $image_formats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    imf = ImageFormat.create(:name => 'foo', :width => 50, :height=> 50, :size=> 'limit')
    login(:tiger) # flush 'visitor'
    assert !imf.new_record?, "Not a new record"
    fmt = ImageFormat['std']
    assert_equal Time.now.utc.strftime('%Y-%m-%d'), $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set to now"
  end
  
  def test_create_bad_attribute
    login(:tiger)
    imf = ImageFormat.create(:name => 'foo', :height=>'34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['width']
    
    imf = ImageFormat.create(:name => 'foo', :height=>'-34', :width => '34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['height']
  end
  
  def test_create_same_name
    login(:tiger)
    imf = ImageFormat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert !imf.new_record?, "Not a new record"
    login(:whale)
    imf = ImageFormat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert imf.new_record?, "New record"
    assert_equal "%{fn} has already been taken", imf.errors['name']
  end
  
  def test_create_update_not_admin
    login(:ant)
    imf = ImageFormat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert imf.new_record?, "New record"
    assert_equal "you do not have the rights to do this", imf.errors['base']
  end
  
  def test_new_from_default
    login(:tiger)
    imf = ImageFormat.new_from_default('pv')
    assert_equal ImageBuilder::DEFAULT_FORMATS['pv'], imf.as_hash
    assert_equal 79, imf[:height]
    assert_equal 70, imf[:width]
    assert_equal 2, imf[:size]
  end
end