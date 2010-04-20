require 'test_helper'

class CalendarTest < Zena::View::TestCase
  include Zena::Use::Calendar::ViewMethods
  include Zena::Use::Refactor::ViewMethods # fquote
  include Zena::Use::I18n::ViewMethods # _
  include Zena::Use::Urls::ViewMethods # data_path

  def test_cal_weeks
    login(:tiger)
    weeks = []
    event_hash = nil
    assert_equal "0", _('week_start_day') # week starts on Sunday
    start_date, end_date = cal_start_end(Time.utc(2006,3,18), :month)
    assert_equal Date.civil(2006,02,26), start_date
    assert_equal Date.civil(2006,04,01), end_date
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :node_name => 'foobar', :event_at => Time.utc(2006,03,20))}
    nodes = secure!(Note) { Note.find(:all, :conditions => ["nodes.event_at >= ? AND nodes.event_at <= ?", start_date, end_date])}
    res = cal_weeks('event_at', nodes, start_date, end_date) do |week, hash|
      weeks << week
      event_hash = hash
    end
    assert_equal ["2006-03-18 00", "2006-03-20 00"], event_hash.keys.sort
    assert_equal ['opening'], event_hash["2006-03-18 00"].map{|r| r.node_name}
    assert_equal ['foobar'], event_hash["2006-03-20 00"].map{|r| r.node_name}
  end

  def test_cal_weeks_hours
    login(:tiger)
    weeks = []
    event_hash = nil
    hours = [0,12]
    assert_equal "0", _('week_start_day') # week starts on Sunday
    start_date, end_date = cal_start_end(Time.utc(2006,3,18), :month)
    assert_equal Date.civil(2006,02,26), start_date
    assert_equal Date.civil(2006,04,01), end_date
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :node_name => 'morning', :event_at => Time.utc(2006,03,20,9))}
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :node_name => 'afternoon', :event_at => Time.utc(2006,03,20,14))}
    nodes = secure!(Note) { Note.find(:all, :conditions => ["nodes.event_at >= ? AND nodes.event_at <= ?", start_date, end_date])}
    res = cal_weeks('event_at', nodes, start_date, end_date, hours) do |week, hash|
      weeks << week
      event_hash = hash
    end
    assert_equal ["2006-03-18 12", "2006-03-20 00", "2006-03-20 12"], event_hash.keys.sort
    assert_equal ['opening'], event_hash["2006-03-18 12"].map{|r| r.node_name}
    assert_equal ['morning'], event_hash["2006-03-20 00"].map{|r| r.node_name}
    assert_equal ['afternoon'], event_hash["2006-03-20 12"].map{|r| r.node_name}
  end
end