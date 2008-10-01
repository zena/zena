require File.dirname(__FILE__) + '/../test_helper'
require 'data_entries_controller'

# Re-raise errors caught by the controller.
class DataEntriesController; def rescue_action(e) raise e end; end

class DataEntriesControllerTest < ZenaTestController
  
  def setup
    super
    @controller = DataEntriesController.new
    init_controller
  end
  
  def test_create
    login(:ant)
    post 'create', :data_entry => {:node_a_id => nodes_zip(:wiki), :date => '17.05.2008 15:00', :value => '34', :text => 'this is a test', :node_b_id => 'people'}
    assert_redirected_to :action => 'show'
    dat = assigns['data_entry']
    assert_kind_of DataEntry, dat
    assert !dat.new_record?, "Not a new record"
    assert_equal 'this is a test', dat[:text]
    assert_equal 34, dat.value
    assert_equal Time.utc(2008,05,17,13), dat[:date]
    assert_equal '17.05.2008 15:00', format_date(dat[:date], '%d.%m.%Y %H:%M')
    assert_equal nodes_id(:people), dat[:node_b_id]
    assert_equal sites_id(:zena), dat[:site_id]
  end
end
