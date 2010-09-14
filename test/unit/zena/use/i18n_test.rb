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

  context 'With a translation dict' do
    setup do
      login(:anon)
      visitor.lang = 'fr'
    end

    subject do
      Zena::Use::I18n::TranslationDict.new(nodes_id(:translations))
    end

    should 'load data on first request' do
      assert_nil subject.instance_variable_get(:@dict)
      assert_equal "j'aime", subject['I love']
      assert_kind_of Hash, subject.instance_variable_get(:@dict)
      assert_equal "foo", subject.get('foo')
    end

    should 'load data in new object' do
      visitor.lang = 'de'
      assert_equal "Ich liebe", subject.get('I love')
      visitor.lang = 'fr'
      # should not reload
      assert_equal "Ich liebe", subject.get('I love')
    end
  end # With a translation dict

end