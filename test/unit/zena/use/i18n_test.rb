require 'test_helper'

class I18nTest < Zena::View::TestCase
  def self.prepend_before_filter(*args); end
  def self.before_filter(*args); end
  def self.after_filter(*args); end
  
  include Zena::Use::I18n::ViewMethods
  include Zena::Use::I18n::ControllerMethods
  include Zena::Use::Refactor::ViewMethods # fquote
  include Zena::Use::Urls::ViewMethods # data_path
  
  def params
    @params ||= {}
  end
  
  def setup
    super
    I18n.locale = 'en'
  end

  def test_trans
    assert_equal 'yoba', _('yoba')
    assert_equal '%A, %B %d %Y', _('full_date')
    I18n.locale = 'fr'
    assert_equal '%A, %d %B %Y', _('full_date')
  end
end