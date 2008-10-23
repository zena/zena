require File.dirname(__FILE__) + '/../test_helper'

class IformatTest < ZenaTestUnit
  
  def setup
    super
    $iformats = nil # also works without this, but the tests are more reliable with it
  end
  
  def test_default_format
    login(:lion)
    assert_equal ({:width=>70, :height=>70, :size=>:force, :gravity => Magick::CenterGravity, :name=>'pv'}), Iformat['pv']
  end
  
  def test_redefined_format
    login(:lion)
    fmt = Iformat['med']
    assert_not_equal ImageBuilder::DEFAULT_FORMATS['med'], fmt
    assert_equal ({:name => 'med', :width=>300, :height=>200, :gravity=>Magick::CenterGravity, :size=>:limit}), fmt
  end
  
  def test_other_site
    login(:whale)
    assert_equal ImageBuilder::DEFAULT_FORMATS['med'], Iformat['med']
  end
  
  def test_defined_format
    login(:lion)
    assert_nil Iformat['header']
    login(:whale)
    assert_equal ({:name => 'header', :gravity=>Magick::NorthGravity, :width=>688, :size=>:force, :height=>178}), Iformat['header']
  end
  
  def test_list
    login(:lion)
    assert_equal %w{tiny mini pv square top low med side edit std full}, Iformat.list.map{|h| h[:name]}
    
    login(:whale)
    assert_equal %w{tiny mini pv square med top low side header edit std full}, Iformat.list.map{|h| h[:name]}
  end
  
  def test_mem_cached
    login(:whale)
    assert_equal 688, Iformat['header'][:width]
    Iformat.connection.execute "UPDATE iformats SET width = 500 WHERE id = #{iformats_id(:header)}"
    assert_equal 688, Iformat['header'][:width]
    $iformats = nil
    assert_equal 688, Iformat['header'][:width]
  end
  
  def test_update_expire_mem_cache
    login(:lion)
    assert_equal 300, Iformat['med'][:width]
    assert_equal '2008-05-01', $iformats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = Iformat['med']
    assert_equal fmt1.object_id, Iformat['med'].object_id, "In cache"
    
    # Update format
    assert Iformat.update(iformats_id(:med), :width => 350)
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:lion) # flush visitor (new web query)
    assert_equal now, visitor.site[:formats_updated_at].strftime('%Y-%m-%d'), "Site's formats update date changed"
    
    # format hasn't change in memory yet
    assert_equal 300, $iformats[sites_id(:zena)]['med'][:width], "Mem cached version not changed"
    
    fmt2 = Iformat['med'] # updates cache
    
    assert_equal 350, fmt2[:width], "Updated value"
    assert_equal now, $iformats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, Iformat['med'].object_id, "In cache"
  end
  
  def test_destroy_expire_mem_cache
    login(:lion)
    assert_equal 300, Iformat['med'][:width]
    assert_equal '2008-05-01', $iformats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d')
    assert_equal '2008-05-01', visitor.site[:formats_updated_at].strftime('%Y-%m-%d')
    fmt1 = Iformat['med']
    assert_equal fmt1.object_id, Iformat['med'].object_id, "In cache"
    
    # Destroy format
    assert Iformat.destroy(iformats_id(:med))
    now = Time.now.utc.strftime('%Y-%m-%d')
    
    
    login(:lion) # flush visitor (new web query)
    assert_nil visitor.site[:formats_updated_at], "Site's formats update date is NULL"
    
    # format hasn't change in memory yet
    assert_equal 300, $iformats[sites_id(:zena)]['med'][:width], "Mem cached version not changed"
    
    fmt2 = Iformat['med'] # updates cache
    
    assert_equal 280, fmt2[:width], "Default value"
    assert_nil $iformats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    assert_not_equal fmt1.object_id, fmt2.object_id, "Cache changed"
    
    assert_equal fmt2.object_id, Iformat['med'].object_id, "In cache"
  end

  def test_update_expire_cache_and_formated_images
    login(:lion)
    bird = secure(Node) { nodes(:bird_jpg) }
    assert bird.c_file(Iformat['med']) # force creation of bird_med.jpg
    assert File.exist?(bird.c_filepath(Iformat['med']))
    # Update format
    assert Iformat.update(iformats_id(:med), :width => 350)
    assert !File.exist?(bird.c_filepath(Iformat['med'])), "Calculated image removed"
    assert File.exist?(bird.c_filepath), "Original not removed"
  end
  
  def test_create_first
    login(:lion)
    assert Iformat.destroy(iformats_id(:med))
    fmt = Iformat['med']
    assert_nil $iformats[sites_id(:zena)][:updated_at], "Cache date set to nil"
    imf = Iformat.create(:name => 'foo', :width => 50, :height=> 50, :size=> 'limit')
    assert !imf.new_record?, "Not a new record"
    login(:lion) # flush 'visitor'
    fmt = Iformat['med']
    assert_equal Time.now.utc.strftime('%Y-%m-%d'), $iformats[sites_id(:zena)][:updated_at].strftime('%Y-%m-%d'), "Cache date set to now"
  end
  
  def test_cannot_change_full
    login(:lion)
    imf = Iformat.create(:name => 'full', :width => 50, :height=> 50, :size=> 'limit')
    assert imf.new_record?
    assert imf.errors['name'], "Cannot change 'full' format."
    login(:lion) # flush 'visitor'
    fmt = Iformat['full']
    assert :keep, fmt[:size]
  end
  
  def test_create_bad_attribute
    login(:lion)
    imf = Iformat.create(:name => 'foo', :height=>'34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['width']
    
    imf = Iformat.create(:name => 'foo', :height=>'-34', :width => '34', :size => 'limit')
    assert imf.new_record?, "New record"
    assert "must be greater then 0", imf.errors['height']
  end
  
  def test_create_same_name
    login(:lion)
    imf = Iformat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert !imf.new_record?, "Not a new record"
    login(:whale)
    imf = Iformat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert imf.new_record?, "New record"
    assert_equal "Name has already been taken", imf.errors['name']
  end
  
  def test_create_update_not_admin
    login(:ant)
    imf = Iformat.create(:name => 'header', :height=>'34', :width => '500', :size => 'force')
    assert imf.new_record?, "New record"
    assert_equal "you do not have the rights to do this", imf.errors['base']
  end
  
  def test_new_from_default
    login(:lion)
    imf = Iformat.new_from_default('pv')
    assert_equal ImageBuilder::DEFAULT_FORMATS['pv'], imf.as_hash
    assert_equal 70, imf[:height]
    assert_equal 70, imf[:width]
    assert_equal 2, imf[:size]
  end
end