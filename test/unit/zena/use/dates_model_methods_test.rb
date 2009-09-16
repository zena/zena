require 'test_helper'

class DatesModelMethodsTest < Zena::Unit::TestCase
  include Zena::Use::I18n::ViewMethods # _

  class Foo < ActiveRecord::Base
    set_table_name 'nodes'
    include Zena::Use::Dates::ModelMethods
    parse_date_attribute :event_at, :log_at
  end

  def setup
    super
    I18n.locale = 'en'
    visitor.time_zone = 'UTC'
  end

  def test_should_parse_string_as_date
    node = secure(Foo) { Foo.new('event_at' => '2009-09-09 13:08') }
    assert_equal Time.utc(2009,9,9,13,8), node.event_at
  end

  def test_should_use_i18n_format
    I18n.locale = 'fr' # datetime format = %d-%m-%Y ...
    node = secure(Foo) { Foo.new('event_at' => '9-9-2009 13:08') }
    assert_equal Time.utc(2009,9,9,13,8), node.event_at
  end

  def test_should_use_visitor_time_zone
    visitor.time_zone = "Asia/Jakarta" # UTC+7
    node = Foo.new('log_at' => '2009-09-09 13:08')
    assert_equal Time.utc(2009,9,9,6,8), node.log_at
  end

  def test_should_not_act_on_attributes_not_declared
    visitor.time_zone = "Asia/Jakarta" # UTC+7
    I18n.locale = 'fr' # datetime format = %d-%m-%Y ...
    node = Foo.new('updated_at' => '2009-09-09 13:08')
    assert_equal Time.utc(2009,9,9,13,8), node.updated_at
  end
end