require File.dirname(__FILE__) + '/../test_helper'
require 'note_controller'

# Re-raise errors caught by the controller.
class NoteController; def rescue_action(e) raise e end; end

class NoteControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    @controller = NoteController.new
    init_controller
  end

  def test_day_list
    opening = secure(Item) { items(:opening) }
    get 'day_list', :id=>opening.project_id, :find=>'news', :using=>'log_at', :date=>opening.log_at.strftime('%Y-%m-%d'), :selected=>opening[:id].to_s
    assert_response :success
    assert_tag :li, :attributes=>{:class=>'note'}, :descendant=>{:tag=>'span', :attributes=>{:id=>"v_title#{opening.v_id}"}, :content=>'parc opening'}
  end

  def test_create_without_rights
    post 'create', :note=>{:klass=>'Note', :log_at=>'2006-10-03 15:20', :parent_id=>items_id(:zena), :v_title=>'this is a test'}
    assert_response :success
    assert assigns['note'].new_record?
    assert_equal 'invalid reference', assigns['note'].errors[:parent_id]
  end

  def test_create_bad_parent
    post 'create', :note=>{:klass=>'Note', :log_at=>'2006-10-03 15:20', :parent_id=>items_id(:status), :v_title=>'this is a test'}
    assert_response :success
    assert assigns['note'].new_record?
    assert_equal 'invalid reference', assigns['note'].errors[:parent_id]
  end

  def test_create_bad_klass
    login(:tiger)
    post 'create', :note=>{:klass=>'system "pwd"', :log_at=>'2006-10-03 15:20', :parent_id=>items_id(:zena), :v_title=>'this is a test'}
    assert_response :success
    note = assigns['note']
    assert_equal 'invalid', note.errors[:klass]
    assert_equal 'system "pwd"', note.klass

    post 'create', :note=>{:klass=>'Item', :parent_id=>items_id(:zena), :name=>'test'}
    assert_response :success
    note = assigns['note']
    assert_equal 'invalid', note.errors[:klass]
    assert_equal 'Item', note.klass
  end

  def test_create_ok
    login(:tiger)
    post 'create', :note=>{:klass=>'Note', :log_at=>'2006-10-03 15:20', :parent_id=>items_id(:zena), :v_title=>'this is a test'}
    assert_response :success
    note = assigns['note']
    assert_kind_of Note, note
    assert !note.new_record?, "Not a new record"
    assert_equal Time.gm(2006,10,3,15,20), note.log_at
    assert_equal Time.gm(2006,10,3,15,20), note.event_at
  end
end
