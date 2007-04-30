require File.dirname(__FILE__) + '/../test_helper'

class SkinTest < ZenaTestUnit

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
    assert_equal nodes_id(:layout), tmpl[:id]
    tmpl = skin.template_for_path('bad')
    assert_nil tmpl
  end
  
  def test_name_change
    login(:lion)
    skin = secure(Node) { nodes(:wiki_skin) }
    tmpt = secure(Node) { nodes(:layout)    }
    assert_equal 'wiki', skin.name
    assert_equal 'wiki', tmpt.c_skin_name
    skin.name = 'fun'
    assert skin.save, "Can save skin."
    tmpt = secure(Node) { nodes(:layout)    } # reload
    assert_equal 'fun', tmpt.c_skin_name
    assert_equal 'fun', secure(Node) { nodes(:wiki_page_changes) }.c_skin_name
  end
end