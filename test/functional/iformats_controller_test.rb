require 'test_helper'

class IformatsControllerTest < Zena::Controller::TestCase
  
  def test_only_admin_can_create
    login(:tiger)
    post 'create', :iformat=>{:name => 'super', :size => 'limit', :height => 20, :width => 20}
    assert_response 404
  end
  
  def test_create_new
    login(:lion)
    post 'create', :iformat=>{:name => 'super', :size => 'limit', :height => 20, :width => 20}
    assert_response :success
    imf = assigns['iformat']
    assert_kind_of Iformat, imf
    err imf
    assert !imf.new_record?, "Not a new record"
    assert_equal 'super', imf[:name]
    assert_equal Iformat::SIZES.index('limit'), imf[:size]
    assert_equal sites_id(:zena), imf[:site_id]
  end
  
  def test_create_same_name
    login(:lion)
    post 'create', :iformat=>{:name => 'med', :size => 'limit', :height => 20, :width => 20}
    assert_response :success
    imf = assigns['iformat']
    assert imf.new_record?, "New record"
    assert imf.errors[:name].any?
  end
  
  def test_update
    login(:lion)
    assert_equal 300, Iformat['med'][:width]
    put 'update', :id => iformats_id(:med), :iformat=>{:size => 'limit', :width=>250, :height=>300}
    assert_redirected_to :action => 'show'
    imf = assigns['iformat']
    assert !imf.new_record?, "New record"
    assert_equal 250, imf[:width]
    login(:lion)
    assert_equal 250, Iformat['med'][:width]
  end
  
  def test_update_default
    # creates a new record
    login(:lion)
    assert_equal 70, Iformat['pv'][:width]
    put 'update', :id => 'pv', :iformat=>{:size => 'limit', :width=>80, :height=>80}
    assert_redirected_to :action => 'show'
    imf = assigns['iformat']
    assert !imf.new_record?, "New record"
    assert_equal 80, imf[:width]
    login(:lion)
    assert_equal 80, Iformat['pv'][:width]
  end
  
  def test_update_change_name_restore_default
    login(:lion)
    assert_equal 300, Iformat['med'][:width]
    put 'update', :id => iformats_id(:med), :iformat=>{:name => 'moo'}
    assert_redirected_to :action => 'show'
    imf = assigns['iformat']
    assert !imf.new_record?, "New record"
    assert_equal 300, imf[:width]
    login(:lion)
    assert_equal 280, Iformat['med'][:width]
  end
  
  def test_update_bad_name
    login(:lion)
    Iformat.create(:name => 'foo', :width => 50, :height=> 50, :size=> 'limit')
    put 'update', :id => iformats_id(:med), :iformat=>{:name=>'foo'}
    assert_template 'edit'
    imf = assigns['iformat']
    assert imf.errors[:name].any?
  end
  
  def test_edit
    login(:lion)
    get 'edit', :id => iformats_id(:med)
    assert_response :success
    assert_template 'edit'
    assert_equal iformats_id(:med), assigns['iformat'][:id]
  end
  
  def test_index
    login(:lion)
    get 'index'
    assert_response :success
    assert_template 'index'
    iformats = assigns['iformats']
    assert_equal 11, iformats.size
  end
  
  def test_show
    login(:lion)
    get 'show', :id => iformats_id(:med)
    assert_response :success
  end
  
  def test_show_not_admin
    get 'show', :id => iformats_id(:med)
    assert_response 404
  end
  
  def test_destroy
    login(:lion)
    delete 'destroy', :id => iformats_id(:med)
    assert_redirected_to :action => 'index'
    assert_nil Iformat.find(:first, :conditions => "id = #{iformats_id(:med)}")
    login(:lion)
    assert_equal 280, Iformat['med'][:width]
  end
end
