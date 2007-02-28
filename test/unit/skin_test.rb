require File.dirname(__FILE__) + '/../test_helper'

class SkinTest < Test::Unit::TestCase
  include ZenaTestUnit

  def test_template_url_for_name
    without_files('app/views/templates/compiled') do
      skin = secure(Skin) { Skin.find_by_name('wiki')}
      assert_kind_of Skin, skin
      path = File.join(RAILS_ROOT, 'app', 'views', 'templates', 'compiled', 'wiki', 'any_en.rhtml')
      assert !File.exist?(path), "File does not exist"
      assert_equal "/templates/compiled/wiki/any_en", skin.template_url_for_name('any', nil)
      assert File.exist?(path), "File exists"
      path = File.join(RAILS_ROOT, 'app', 'views', 'templates', 'compiled', 'wiki', 'layout_en.rhtml')
      assert !File.exist?(path), "File does not exist"
      assert_equal "/templates/compiled/wiki/layout_en", skin.template_url_for_name('layout', nil)
      assert File.exist?(path), "File exists"
      assert_equal nil, skin.template_url_for_name('bad', nil)
    end
  end
  
  def test_template_for_path
    skin = secure(Skin) { Skin.find_by_name('wiki')}
    assert_kind_of Skin, skin
    tmpl = skin.template_for_path('any')
    assert_equal tmpl, skin
    tmpl = skin.template_for_path('layout')
    assert_equal nodes_id(:wiki_layout), tmpl[:id]
    tmpl = skin.template_for_path('bad')
    assert_nil tmpl
  end
end