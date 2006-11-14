require File.dirname(__FILE__) + '/../../test_helper'

class MainHelperTest < Test::Unit::TestCase
  fixtures :versions, :comments, :items, :addresses, :groups, :groups_users, :trans_keys, :trans_values
  include ZenaTestHelper
  include ApplicationHelper
  include MainHelper

  def test_check_lang_same
    session[:lang] = 'en'
    obj = items(:zena)
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    session[:lang] = 'io'
    obj = items(:zena)
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_change_lang
    assert_equal ({:overwrite_params=>{:prefix=>'io'}}), change_lang('io')
    login(:ant)
    assert_equal ({:overwrite_params=>{:lang=>'io'}}), change_lang('io')
  end
  
  def test_edit_button_for_public
    @item = secure(Item) { Item.find(items_id(:cleanWater)) }
    assert !@item.can_edit?, "Item cannot be edited by the public"
    res = edit_button(:all)
    assert_equal '', res
  end
  
  def test_edit_button_wiki_public
    @item = secure(Item) { Item.find(items_id(:wiki)) } 
    assert @item.can_edit?, "Item can be edited by the public"
    res = edit_button(:all)
    assert_match %r{/z/version/edit/19}, res
    assert_match %r{/z/item/drive\?.*version_id=19}, res
  end
  
  def test_item_actions_for_ant
    login(:ant)
    @item = secure(Item) { Item.find(items_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match    %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_item_actions_for_tiger
    login(:tiger)
    @item = secure(Item) { Item.find(items_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/item/drive}, res
    @item.edit
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/version/propose}, res
    assert_match %r{/z/version/publish}, res
    assert_match %r{/z/item/drive}, res
    @item.save
    login(:ant)
    session[:lang] = 'fr'
    @item = secure(Item) { Item.find(items_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
    session[:lang] = 'en'
    @item = secure(Item) { Item.find(items_id(:cleanWater)) }
    res = edit_button(:all)
    assert_no_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_traductions
    session[:lang] = 'en'
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'main', :action=>'index'} ) }
    @item = secure(Item) { Item.find(items_id(:status)) } # en,fr
    trad = traductions
    assert_equal 2, trad.size
    assert_match /class='on'.*href="\/en"/, trad[0]
    assert_no_match /class='on'/, trad[1]
    @item = secure(Item) { Item.find(items_id(:cleanWater)) } #  en
    trad = traductions
    assert_equal 1, trad.size
    session[:lang] = 'io'
    trad = traductions
    assert_equal 2, trad.size
    assert_match /class='off'/, trad[1]
  end
  
  def test_author
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'main', :action=>'index'} ) }
    @item = Item.find(items_id(:projects))
    session[:lang] = 'en'
    assert_match /class='info'.*posted by.*Panther Tigris Sumatran.*on 04.11.*Traductions :/m , author(:large)
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author(:small)
    @item = secure(Item) { Item.find(items_id(:opening)) }
    assert_equal addresses_id(:tiger), @item.v_author[:id]
    assert_match /class='info'.*posted by.*Panther Tigris Sumatran/m, author(:large)
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author
    session[:lang] = 'fr'
    @item = secure(Item) { Item.find(items_id(:opening)) }
    assert_equal addresses_id(:ant), @item.v_author[:id]
    assert_match /class='info'.*original by.*Panther Tigris Sumatran.*new post by.*Solenopsis Invicta/m, author(:large)
    assert_equal "<div class='info'><b>SI</b> - 11.04</div>", author
  end
  
  def test_path_links_root
    @item = secure(Item) { Item.find(items_id(:zena))}
    assert_equal "<ul id='path' class='path'><li><a href='/en'>zena</a></li></ul>", path_links
    item2 = @item
    @item = secure(Item) { Item.find(items_id(:status))}
    assert_equal "<ul class='path'><li><a href='/en'>zena</a></li></ul>", path_links(item2)
  end
  
  def test_path_links_root_with_login
    login(:ant)
    @item = secure(Item) { Item.find(items_id(:zena))}
    assert_equal "<ul id='path' class='path'><li><a href='/#{AUTHENTICATED_PREFIX}'>zena</a></li></ul>", path_links
  end
  
  def test_path_links_page
    @item = secure(Item) { Item.find(items_id(:cleanWater))}
    assert_match %r{<ul id='path'.*href='/en'>zena.*href='/en/projects'>projects.*href='/en/projects/cleanWater'>cleanWater}, path_links
  end
  
end
  
  