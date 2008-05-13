require File.dirname(__FILE__) + '/../test_helper'

class ImageFormatTest < ZenaTestUnit
  
  def setup
    super
    $image_formats = nil # also works without this, but the tests are more reliable with it
  end
  
  def test_default_format
    login(:lion)
    assert_equal ({:width=>70, :height=>70, :size=>:force, :gravity => Magick::CenterGravity, :name=>'pv'}), ImageFormat['pv']
  end
  
  def test_redefined_format
    login(:lion)
    fmt = ImageFormat['med']
    assert_not_equal ImageBuilder::DEFAULT_FORMATS['med'], fmt
    assert_equal ({:name => 'med', :width=>300, :height=>200, :gravity=>Magick::CenterGravity, :size=>:limit}), fmt
  end
  
  def test_other_site
    login(:whale)
    assert_equal ImageBuilder::DEFAULT_FORMATS['med'], ImageFormat['med']
  end
  
  def test_defined_format
    login(:lion)
    assert_nil ImageFormat['header']
    login(:whale)
    assert_equal ({:name => 'header', :gravity=>Magick::NorthGravity, :width=>688, :size=>:force, :height=>178}), ImageFormat['header']
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
    login(:lion)
    assert_equal 300, ImageFormat['med'][:width]
    assert_equal '2008-05-01', $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = ImageFormat['med']
    assert_equal fmt1.object_id, ImageFormat['med'].object_id, "In cache"
    
    # Update format
    assert ImageFormat.update(image_formats_id(:redifined_med), :width => 350)
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:lion) # flush visitor (new web query)
    assert_equal now, visitor.site[:formats_updated_at].strftime('%Y-%m-%d'), "Site's formats update date changed"
    
    # format hasn't change in memory yet
    assert_equal 300, $image_formats[sites_id(:zena)]['med'][:width], "Mem cached version not changed"
    
    fmt2 = ImageFormat['med'] # updates cache
    
    assert_equal 350, fmt2[:width], "Updated value"
    assert_equal now, $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, ImageFormat['med'].object_id, "In cache"
  end
  
  def test_destroy_expire_mem_cache
    login(:lion)
    assert_equal 300, ImageFormat['med'][:width]
    assert_equal '2008-05-01', $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = ImageFormat['med']
    assert_equal fmt1.object_id, ImageFormat['med'].object_id, "In cache"
    
    # Destroy format
    assert ImageFormat.destroy(image_formats_id(:redifined_med))
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:lion) # flush visitor (new web query)
    assert_nil visitor.site[:formats_updated_at], "Site's formats update date is NULL"
    
    # format hasn't change in memory yet
    assert_equal 300, $image_formats[sites_id(:zena)]['med'][:width], "Mem cached version not changed"
    
    fmt2 = ImageFormat['med'] # updates cache
    
    assert_equal 280, fmt2[:width], "Default value"
    assert_nil $image_formats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, ImageFormat['med'].object_id, "In cache"
  end
  
  def test_create_first
    login(:lion)
    assert ImageFormat.destroy(image_formats_id(:redifined_med))
    fmt = ImageFormat['med']
    assert_nil $image_formats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    imf = ImageFormat.create(:name => 'foo', :width => 50, :height=> 50, :size=> 'limit')
    login(:lion) # flush 'visitor'
    assert !imf.new_record?, "Not a new record"
    fmt = ImageFormat['med']
    assert_equal Time.now.utc.strftime('%Y-%m-%d'), $image_formats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set to now"
  end
  
  def test_create_bad_attribute
    login(:lion)
    imf = ImageFormat.create(:name => 'foo', :height=>'34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['width']
    
    imf = ImageFormat.create(:name => 'foo', :height=>'-34', :width => '34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['height']
  end
  
  def test_create_same_name
    login(:lion)
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
    login(:lion)
    imf = ImageFormat.new_from_default('pv')
    assert_equal ImageBuilder::DEFAULT_FORMATS['pv'], imf.as_hash
    assert_equal 70, imf[:height]
    assert_equal 70, imf[:width]
    assert_equal 2, imf[:size]
  end
end