require File.dirname(__FILE__) + '/../test_helper'

class MultiVersionTest < Test::Unit::TestCase

  include ZenaTestUnit
  def item_defaults
    {
    :name => 'hello',
    :parent_id => 1,
    }
  end
  
  def test_find_version
    visitor(:ant)
    item = secure(Item) { Item.version(versions_id(:lake_red_en)) }
    assert_equal "this is a new redaction for lake", item.comment
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { Item.version(versions_id(:zena_en)) } }
    assert_raise(ActiveRecord::RecordNotFound) { item = secure(Item) { Item.version(versions_id(:secret_en)) } }
    visitor(:lion)
    assert_nothing_raised { item = secure(Item) { Item.version(versions_id(:lake_red_en)) } }
  end
  
  def test_accessors
    visitor(:tiger)
    item = secure(Item) { items(:status) }
    assert_equal "status title", item.title
    assert_equal "status comment", item.comment
    assert_equal "status summary", item.summary
    assert_equal "status text", item.text
  end
  
  def test_new_has_redaction
    visitor(:ant)
    item = secure(Item) { Item.new() }
    assert_equal Zena::Status[:red], item.v_status
    assert_equal addresses_id(:ant), item.v_user_id
  end
  
  def test_new_with_attributes
    visitor(:ant)
    attrs = item_defaults
    attrs[:title] = "Jolly Jumper"
    attrs[:summary] = "Jolly summary"
    attrs[:comment] = "Jolly comment"
    attrs[:text] = "Jolly text"
    item = secure(Item) { Item.new(attrs) }
    assert item.save
    item = secure(Item) { Item.find(item.id) }
    assert_equal Zena::Status[:red], item.v_status
    assert_equal "Jolly Jumper", item.title
    assert_equal "Jolly summary", item.summary
    assert_equal "Jolly comment", item.comment
    assert_equal "Jolly text", item.text
  end
  
  def test_create
    visitor(:ant)
    attrs = item_defaults
    attrs[:title] = "Inner voice"
    item = secure(Item) { Item.create(attrs) }
    item = secure(Item) { Item.find(item.id) }
    assert_equal Zena::Status[:red], item.v_status
    assert_equal "Inner voice", item.title
  end
  
  def test_version_lang
    visitor(:ant) # lang = fr
    item = secure(Item) { items(:opening)  }
    assert_equal "fr", item.v_lang
    assert_equal "ouverture du parc", item.title
    @lang = "en"
    item = secure(Item) { items(:opening)  }
    assert_equal "en", item.v_lang
    assert_equal "parc opening", item.title
    @lang = 'ru'
    item = secure(Item) { items(:opening)  }
    assert_equal "fr", item.v_lang
    assert_equal "ouverture du parc", item.title
    visitor(:lion) # lang = en
    item = secure(Item) { items(:opening)  }
    assert_equal "en", item.v_lang
    assert_equal "parc opening", item.title
    @lang = 'ru'
    item = secure(Item) { items(:opening)  }
    assert_equal "fr", item.v_lang
    assert_equal "ouverture du parc", item.title
  end
  
  def test_version_text_and_summary
    visitor(:ant)
    item = secure(Item) { items(:ant)  }
    class << item
      def text
        "Item:#{super}"
      end
      def summary
        "Item:#{super}"
      end
    end
    assert_equal "Item:Ants work hard", item.text
    assert_equal "Ants work hard", item.v_text
    assert_equal "Item:I am an ant", item.summary
    assert_equal "I am an ant", item.v_summary
  end
  
  def test_editions
    visitor(:ant)
    item = secure(Item) { items(:opening)  }
    editions = item.editions
    assert_equal 2, editions.count
  end
  
  def test_edit_get_redaction
    visitor(:ant)
    item = secure(Item) { items(:opening)  }
    assert_equal "fr", item.v_lang
    assert_equal "french opening", item.comment
  end
  
  def test_set_redaction
    visitor(:tiger)
    set_lang('es')
    item = secure(Item) { items(:status) }
    item.send(:set_redaction, :title, 'labias')
    assert_equal 'es', item.v_lang
    assert_equal 'labias', item.title
    assert item.send(:version).new_record?
  end
  
  def test_proposition
    visitor(:tiger)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    assert_equal Zena::Status[:pub], item.v_status , "Any visitor sees the publication"
    assert_equal versions_id(:lake_en) , item.v_id
    visitor(:ant)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    assert_equal Zena::Status[:red], item.v_status , "Owner of a redaction sees the redaction"
    assert_equal versions_id(:lake_red_en) , item.v_id
    assert item.propose , "Item proposed for publication"
    
    item = secure(Item) { items(:lake)  }
    assert_equal Zena::Status[:prop], item.v_status , "Owner sees the proposition"
    assert_equal versions_id(:lake_red_en) , item.v_id
    
    visitor(nil) # public
    item = secure(Item) { items(:lake)  }
    assert_equal Zena::Status[:pub], item.v_status , "Visitor sees the publication"
    assert_equal versions_id(:lake_en) , item.v_id
    
    visitor(:tiger)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    assert_equal Zena::Status[:prop], item.v_status , "Publisher sees the proposition"
    assert_equal versions_id(:lake_red_en) , item.v_id
  end
  
  def test_can_edit
    visitor(:ant)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    item2 = secure(Item) { items(:status)  }
    assert item.can_edit?
    assert item2.can_edit?
    visitor(:tiger)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    item2 = secure(Item) { items(:status)  }
    assert ! item.can_edit?
    assert item2.can_edit?
  end
  
  def test_do_edit
    visitor(:ant)
    item = secure_write(Item) { items(:wiki)  }
    item.edit!
    assert_equal Zena::Status[:red], item.v_status
    assert item.new_redaction?
  end
  
  def test_update_without_fuss
    visitor(:tiger)
    item = secure(Item) { items(:wiki) }
    assert_equal Zena::Status[:pub], item[:max_status]
    item.send(:update_attribute_without_fuss, :max_status, Zena::Status[:red])
    item = secure(Item) { items(:wiki) }
    assert_equal Zena::Status[:red], item[:max_status]
  end
  
  def test_update_without_fuss_time
    visitor(:tiger)
    item = secure(Item) { items(:wiki) }
    assert_equal Time.local(2006,3,10), item[:publish_from]
    item.send(:update_attribute_without_fuss, :publish_from, Time.local(2006,12,10))
    item = secure(Item) { items(:wiki) }
    assert_equal Time.local(2006,12,10), item[:publish_from]
  end
  
  def test_update_new_red
    visitor(:ant)
    item = secure_write(Item) { items(:wiki)  }
    assert item.edit! , "Edit succeeds"
    attrs = { :comment=>"hey I'm new !", :title=>"super new" }
    assert item.update_redaction( attrs ) , "Edit succeeds"
    assert ! item.new_redaction? , "Not a new redaction"
    assert_equal "super new", item.title
    # find it
    item = secure_write(Item) { items(:wiki)  }
    assert item.edit! , "Edit succeeds"
    assert_equal "hey I'm new !", item.comment
    assert_equal "super new", item.title
    assert_equal Zena::Status[:red], item.v_status
    assert item.update_redaction( :title=>"bee bop a lula" ) , "Edit succeeds"
    assert_equal "bee bop a lula", item.title
    redactions = Version.find(:all, :conditions=>['item_id = ? AND status = ?', items_id(:wiki), Zena::Status[:red]])
    assert_equal 1, redactions.size
    
    # no two redactions for the same language
    visitor(:tiger)
    @lang = "fr"
    item = secure_write(Item) { items(:wiki)  }
    assert ! item.edit! , "Edit fails"
    assert ! item.update_redaction( :title=>"Mon amour") , "Edit fails"
    
    # can add redactions for different languages
    @lang = "de"
    item = secure_write(Item) { items(:wiki)  }
    assert item.update_redaction( :title=> "Spieluhr") , "Edit succeeds"
    redactions = Version.find(:all, :conditions=>['item_id = ? AND status = ?', items_id(:wiki), Zena::Status[:red]])
    assert_equal 2, redactions.size
  end
  
  def test_update_redaction
    visitor(:ant)
    @lang = 'en'
    item = secure_write(Item) { items(:lake)  }
    assert item.edit! , "Edit succeeds"
    assert_equal "The lake we love", item.title
    assert_equal Zena::Status[:red], item.v_status
    attrs = { :comment=>"hey I'm new !", :title=>"super new" }
    assert item.update_redaction( attrs ) , "Edit succeeds"
    
    item = secure_write(Item) { items(:lake)  }
    assert item.edit! , "Edit succeeds"
    assert_equal "hey I'm new !", item.comment
    assert_equal "super new", item.title
    assert_equal Zena::Status[:red], item.v_status
  end
  
  def test_update_redaction_bad_user
    visitor(:tiger)
    item = secure_write(Item) { items(:lake)  }
    assert ! item.edit! , "Edit fails"
    assert_equal Zena::Status[:pub], item.v_status
    attrs = { :comment=>"hey I'm new !", :title=>"super new" }
    assert ! item.update_redaction( attrs ) , "Edit fails"
  end
  
  def test_update_cannot_create_redaction
    # changes item and creates a new redaction
    visitor(:lion)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    attrs = { :rgroup_id => 4, :title => "Manager's lake" }
    assert ! item.update_attributes( attrs ), "Update attributes fails"
    assert item.errors[:title] , "Errors on title"
  end
  
  def test_update_attributes_ok
    # changes item and creates a new redaction
    visitor(:lion)
    @lang = 'ru'
    item = secure(Item) { items(:lake)  }
    attrs = { :rgroup_id => 4, :title => "Manager's lake"}
    assert item.update_attributes( attrs ), "Update attributes succeeds"
    assert_equal 4, item.rgroup_id
    assert_equal 3, item.wgroup_id
    assert_equal 4, item.pgroup_id
    assert_equal 0, item.inherit
    assert_equal "Manager's lake", item.title
  end
  
  def test_create_bad_attributes
    visitor(:ant)
    attrs = {
    :name => 'new_with_attributes',
    :rgroup_id => 3,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => items_id(:secret),
    :title => "A New Item With A Redaction",
    :summary => "new summary"
    }
    item = secure(Item) { Item.new( attrs ) }
    assert ! item.save , "Save fails"
    assert item.errors[:parent_id] , "Errors on parent_id"
  end
  
  def test_create_with_attributes_ok
    visitor(:tiger)
    attrs = {
    :name => 'new_with_attributes',
    :rgroup_id => 3,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => 1,
    :title => "A New Item With A Redaction",
    :summary => "new summary"
    }
    item = secure(Item) { Item.create( attrs ) }
    assert ! item.new_record? , "Not a new record"
    assert ! item.new_redaction? , "Not a new redaction"
    assert_equal Zena::Status[:red], item.v_status
    assert_equal "A New Item With A Redaction", item.title
    assert_equal "new_with_attributes", item.name
    assert_equal 3, item.rgroup_id
  end
  
  def test_save_redaction
    visitor(:ant)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    item.edit!
    version_id = item.v_id
    assert_equal "The lake we love", item.title
    assert_equal versions_id(:lake_red_en), version_id
    # edit item with form...
    # post modifications
    item = secure(Item) { Item.version(item.v_id) }
    assert item.update_redaction( :title => "Funny lake" ) , "Edit succeeds"
    assert_equal "Funny lake", item.title
    assert_equal version_id, item.v_id
    # find redaction again
    item = secure(Item) { items(:lake)  }
    item.edit!
    assert_equal "Funny lake", item.title
    assert_equal version_id, item.v_id
  end
  
  def test_propose_item_ok
    visitor(:ant)
    item = secure(Item) { Item.version(versions_id(:lake_red_en)) }
    assert item.propose, "Propose for publication succeeds"
  end
    
  def test_propose_item_fails
    visitor(:tiger)
    item = secure(Item) { Item.version(versions_id(:lake_red_en)) }
    assert ! item.propose, "Propose for publication fails"
  end
  
  def test_publish_item_ok
    visitor(:ant)
    item = secure(Item) { Item.version(versions_id(:lake_red_en)) }
    assert item.propose, "Propose for publication succeeds"
    visitor(:tiger)
    @lang = 'en'
    item = secure(Item) { items(:lake)  }
    assert_equal versions_id(:lake_red_en), item.v_id, "Publisher sees the proposition"
    assert item.publish
    item = secure(Item) { items(:lake)  }
    assert_equal "The lake we love", item.title
    assert_equal versions_id(:lake_red_en), item.v_id
    assert_equal 1, item.editions.size
  end
  
  def test_publish_item_fails
    visitor(:ant)
    item = secure(Item) { Item.version(versions_id(:lake_red_en)) }
    assert ! item.publish, "Publication fails"
    visitor(:tiger)
    pub_item = secure(Item) { items(:lake)  }
    assert_not_equal pub_item.v_id, versions_id(:lake_red_en)
  end
  
  def test_publish_new_lang
    visitor(:tiger)
    @lang = 'fr'
    item = secure(Item) { items(:lake)  }
    assert_equal 1, item.editions.size, "English edition exists"
    assert item.update_redaction( :title => "Joli petit lac" )
    assert item.publish
    item = secure(Item) { items(:lake)  } # reload
    assert_equal 2, item.editions.size, "English and french editions"
    assert_equal ["en", "fr"], item.traductions.sort
  end
  
  def test_remove
    visitor(:tiger)
    @lang = 'en'
    item = secure(Item) { items(:tiger)  }
    assert_kind_of Item, item
    assert item.remove # remove version
    assert_equal Zena::Status[:rem], item.v_status
    assert_equal Zena::Status[:rem], item.max_status
  end
  
end