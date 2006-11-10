require File.dirname(__FILE__) + '/../../test_helper'

class MainHelperTest < HelperTestCase
  include ApplicationHelper
  include MainHelper
  
  def test_check_lang_same
    session[:lang] = 'en'
    obj = Item.find(1)
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    session[:lang] = 'io'
    obj = Item.find(1)
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_change_lang
    assert_equal ({:overwrite_params=>{:prefix=>'io'}}), change_lang('io')
    login(:ant)
    assert_equal ({:overwrite_params=>{:lang=>'io'}}), change_lang('io')
  end
  
  def test_edit_button_for_public
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    assert !@item.can_edit?, "Item cannot be edited by the public"
    res = edit_button(:all)
    assert_equal '', res
  end
  
  def test_edit_button_wiki_public
    @item = @controller.send(:secure,Item) { Item.find(19) } # 19 wiki 
    assert @item.can_edit?, "Item can be edited by the public"
    res = edit_button(:all)
    assert_match %r{/z/version/edit/19}, res
    assert_match %r{/z/item/drive\?.*version_id=19}, res
  end
  
  def test_item_actions_for_ant
    login(:ant)
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_item_actions_for_tiger
    login(:tiger)
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
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
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
    session[:lang] = 'en'
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = edit_button(:all)
    assert_no_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_traductions
    login(:tiger) # session[:lang] = 'en'
    @item = @controller.send(:secure,Item) { Item.find(12) } # 12 status (en,fr)
    trad = traductions
    assert_equal 2, trad.size
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater (en)
    trad = traductions
    assert_equal 1, trad.size
  end
  
  def test_author
    assert false
  end
  
end
  
  