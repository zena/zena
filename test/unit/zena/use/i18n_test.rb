require 'test_helper'

class I18nTest < Zena::View::TestCase
  
  context 'With a logged in user' do
    setup do
      login(:lion)
      visiting(:cleanWater)
      I18n.locale = 'en'
    end
    
    context 'translating with _' do
      should 'return translation for current lang' do
        assert_equal '%A, %B %d %Y', _('full_date')
        I18n.locale = 'fr'
        assert_equal '%A, %d %B %Y', _('full_date')
      end

      should 'return key on missing translation' do
        assert_equal 'yoba', _('yoba')
      end
    end # translating with _
    
    context 'on lang_links' do
      should 'highlight current lang with em' do
        assert_match %r{<em>en</em>}, lang_links
      end

      should 'change lang with lang param' do
        assert_match %r{href=.*/oo/projects/cleanWater\?lang=.*fr.*}, lang_links
      end
    end # on lang_links
  end # With a logged in user

  context 'Without a login' do
    setup do
      login(:anon)
      I18n.locale = 'en'
      visiting(:cleanWater)
    end
    
    context 'translating with _' do
      should 'return translation for current lang' do
        assert_equal '%A, %B %d %Y', _('full_date')
        I18n.locale = 'fr'
        assert_equal '%A, %d %B %Y', _('full_date')
      end

      should 'return key on missing translation' do
        assert_equal 'yoba', _('yoba')
      end
    end # translating with _
    
    context 'on lang_links' do
      should 'highlight current lang with em' do
        assert_match %r{<em>en</em>}, lang_links
      end

      should 'change lang with prefix' do
        assert_match %r{href=.*/fr/projects/cleanWater.*fr.*}, lang_links
      end
    end # on lang_links
  end # Without a login
end