require 'test_helper'

class I18nTest < Zena::View::TestCase
  include Zena::Use::I18n::ViewMethods
  include Zena::Use::Refactor::ViewMethods # fquote
  include Zena::Use::I18n::ViewMethods # _
  include Zena::Use::Urls::ViewMethods # data_path
  
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
  
  def test_check_lang_same
    I18n.locale = 'en'
    obj = secure!(Node) { nodes(:zena) }
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    visitor.lang = 'es'
    I18n.locale = 'es'
    obj = secure!(Node) { nodes(:zena) }
    assert_match /\[en\]/, check_lang(obj)
  end
end