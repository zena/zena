require File.dirname(__FILE__) + '/../test_helper'
class LinkDummy < ActiveRecord::Base
  acts_as_secure
  acts_as_multiversioned
  set_table_name 'items'
  link :icon, :class_name=>'Image', :unique=>true
  link :tags
  # test reverse links
  link :hot, :class_name=>'LinkDummy', :unique=>true
  link :hot_for, :class_name=>'LinkDummy', :as=>'hot', :as_unique=>true
  link :recipients, :class_name=>'LinkDummy'
  link :letters, :class_name=>'LinkDummy', :as=>'recipient'
  link :wife,    :class_name=>'LinkDummy', :unique=>true, :as_unique=>true
  link :husband, :class_name=>'LinkDummy', :unique=>true, :as=>'wife', :as_unique=>true
  def ref_field; :parent_id; end
  def version_class; DummyVersion; end
end

class DummyVersion < ActiveRecord::Base
  belongs_to :item, :class_name=>'LinkDummy', :foreign_key=>'item_id'
  set_table_name 'versions'
end

class SuperDummy < ActiveRecord::Base
  set_table_name 'addresses'
  link :employees, :class_name=>'SuperDummy'
  link :boss, :class_name=>'SuperDummy', :as=>'employee', :unique=>true
end

class LinkTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def setup
    super
    # cleanWater, status, wiki
    LinkDummy.connection.execute "UPDATE items SET type='LinkDummy' WHERE id IN (11,12,18,19);"
    # 'menu' Tag si private for tiger
    LinkDummy.connection.execute "UPDATE items SET inherit=0, rgroup_id=NULL, wgroup_id=NULL, pgroup_id=NULL WHERE id = '25';"
  end
  
  def test_link_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nil @item.icon
    @item.icon_id = 20
    assert @item.save
    assert_equal 20, @item.icon_id
    assert_kind_of Image, icon = @item.icon
    assert_equal 20, icon[:id]
    assert_equal "bird", icon.name
  end
  
  def test_link_on_create
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.create(:parent_id=>1, :name=>'lalatest', :tag_ids=>[items_id(:art).to_s,items_id(:news).to_s])}
    assert ! @item.new_record?, "Not a new record"
    assert_equal items_id(:art), @item.tags[0][:id]
  end
  
  def test_bad_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nil @item.icon
    @item.icon_id = 'hello'
    assert_nil @item.icon
    @item.icon_id = 4 # bad class
    @item.save
    assert_equal 0, Link.find_all_by_source_id_and_role(19, 'icon').size
    @item.icon_id = 13645
    @item.save
    assert_equal 0, Link.find_all_by_source_id_and_role(19, 'icon').size
  end
  
  def test_unique_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nil @item.icon
    @item.icon_id = 20
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = 21
    @item.save
    assert_equal 21, @item.icon[:id]
    assert_equal 1, Link.find_all_by_source_id_and_role(19, 'icon').size
  end
  
  def test_remove_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nothing_raised { @item.icon_id = nil }
    @item.icon_id = 20
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = nil
    @item.save
    assert_nil @item.icon
    @item.icon_id = '20'
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = ''
    @item.save
    assert_nil @item.icon
  end
  
  def test_many_tags
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nothing_raised { @item.tags }
    assert_equal [], @item.tags
    @item.tag_ids = [items_id(:art),items_id(:news)]
    @item.save
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @item.tag_ids = [items_id(:art)]
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end
  
  def test_many_tags_with_direct_set
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    assert_nothing_raised { @item.tags }
    assert_equal [], @item.tags
    @item.tags = [items(:art),items(:news)]
    @item.save
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @item.tags = [items(:art)]
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end
  
  def test_can_remove_tag
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @item.tag_ids = [items_id(:art),items_id(:news)]
    @item.save
    assert_equal 2, @item.tags.size
    @item.remove_tag(items_id(:art))
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'news', tags[0].name
  end

  def test_can_add_tag
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @item.add_tag(items_id(:news))
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'news', tags[0].name
  end
  
  def test_can_set_empty_array
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @item.tag_ids = [items_id(:news), items_id(:art)]
    @item.save
    assert_equal 2, @item.tags.size
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @item.tag_ids = []
    @item.save
    assert_equal 0, @item.tags.size
  end

  def test_hot_for
    visitor(:lion)
    @source = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @target = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @source.hot_id = @target[:id]
    @source.save
    assert_equal @target[:name], @source.hot[:name]
    assert_equal @source[:name], @target.hot_for[0][:name]
  end
  
  def test_set_hot_for
    visitor(:lion)
    @source = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @target = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @target.hot_for = [@source]
    @target.save
    assert_equal @target[:name], @source.hot[:name]
    assert_equal @source[:name], @target.hot_for[0][:name]
  end
  
  def test_hot_for_as_unique
    visitor(:lion)
    @source1 = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @source2 = secure(LinkDummy) { LinkDummy.find(items_id(:wiki)) }
    @target1 = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @target2 = secure(LinkDummy) { LinkDummy.find(items_id(:bananas)) }
    @source1.hot = @target1
    @source1.save
    assert_equal @target1[:name], @source1.hot[:name]
    assert_equal @source1[:name], @target1.hot_for[0][:name]
    @target2.hot_for_ids = [@source1.id, @source2.id]
    @target2.save
    assert_equal @target2[:name], @source1.hot[:name]
    assert_equal @target2[:name], @source2.hot[:name]
    assert_equal @source1[:name], @target2.hot_for[0][:name]
    @target2.hot_for = [@source1, @source2]
    @target2.save
    assert_equal @target2[:name], @source1.hot[:name]
    assert_equal @target2[:name], @source2.hot[:name]
    assert_equal @source1[:name], @target2.hot_for[0][:name]
    assert_equal 1, Link.find_all_by_source_id_and_role(@source1.id, 'hot').size
    assert_equal 2, Link.find_all_by_target_id_and_role(@target2.id, 'hot').size
  end
  
  def test_recipients_and_letters
    visitor(:lion)
    @source  = secure(LinkDummy) { LinkDummy.find(items_id(:wiki))  }
    @target1 = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @target2 = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @source.recipient_ids = [11,12]
    @source.save
    assert_equal 2, @source.recipients.size
    assert_equal @source[:name], @target1.letters[0][:name]
    assert_equal @source[:name], @target2.letters[0][:name]
    @target1.remove_letter(items_id(:wiki))
    @target1.save
    assert_equal 1, @source.recipients.size
    assert_equal [], @target1.letters
    assert_equal @source[:name], @target2.letters[0][:name]
  end
  
  def test_cannot_remove_hidden_with_set_ids
    visitor(:tiger)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @item.tag_ids = [items_id(:art),items_id(:news),items_id(:menu)]
    assert @item.save
    tags = @item.tag_ids
    assert_equal 3, tags.size
    assert tags.include?(items_id(:menu)), "Contains the private tag 'menu'"
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    tags = @item.tag_ids
    assert_equal 2, tags.size
    assert !tags.include?(items_id(:menu)), "Does not contain the private tag 'menu'"
    @item.tag_ids = [items_id(:art)]
    assert @item.save
    assert_equal 1, @item.tags.size
    visitor(:tiger)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    tags = @item.tag_ids
    assert_equal 2, tags.size
    assert tags.include?(items_id(:menu)), "Contains the private tag 'menu'"
  end
  
  def test_cannot_remove_hidden_with_remove
    visitor(:tiger)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @item.tag_ids = [items_id(:art),items_id(:news),items_id(:menu)]
    assert @item.save
    tags = @item.tag_ids
    assert_equal 3, tags.size
    assert tags.include?(items_id(:menu)), "Contains the private tag 'menu'"
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    tags = @item.tag_ids
    assert_equal 2, tags.size
    assert !tags.include?(items_id(:menu)), "Does not contain the private tag 'menu'"
    @item.remove_tag(items_id(:news))
    @item.remove_tag(items_id(:menu))
    assert @item.save
    assert_equal 1, @item.tags.size
    visitor(:tiger)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    tags = @item.tag_ids
    assert_equal 2, tags.size
    assert tags.include?(items_id(:menu)), "Contains the private tag 'menu'"
  end
  
  def test_husband_and_wife
    visitor(:tiger)
    @husband  = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @wife     = secure(LinkDummy) { LinkDummy.find(items_id(:wiki))  }
    @husband2 = secure(LinkDummy) { LinkDummy.find(items_id(:status))  }
    
    @husband.wife_id = @wife.id
    assert @husband.save
    assert_equal @husband.id, @wife.husband.id
    assert_equal @wife.id, @husband.wife.id
    @wife.husband_id = @husband2.id
    @wife.save
    assert_equal @husband2.id, @wife.husband.id
    assert_equal @wife.id, @husband2.wife.id
    assert_nil @husband.wife
  end
  
  def test_husband_and_wife_with_direct_set
    visitor(:tiger)
    @husband  = secure(LinkDummy) { LinkDummy.find(items_id(:cleanWater)) }
    @wife     = secure(LinkDummy) { LinkDummy.find(items_id(:wiki))  }
    @husband2 = secure(LinkDummy) { LinkDummy.find(items_id(:status))  }

    @husband.wife = @wife
    assert @husband.save
    assert_equal @husband.id, @wife.husband.id
    assert_equal @wife.id, @husband.wife.id
    @wife.husband = @husband2
    @wife.save
    assert_equal @husband2.id, @wife.husband.id
    assert_equal @wife.id, @husband2.wife.id
    assert_nil @husband.wife
  end
  
  def test_tags_for_form
    visitor(:tiger)
    @item = secure(LinkDummy) { LinkDummy.find(items_id(:status)) }
    @item.tag_ids = [items_id(:art)]
    assert @item.save
    assert_equal 1, @item.tags.size
    tags_for_form = @item.tags_for_form
    assert_equal 3, tags_for_form.size
    assert tags_for_form[0][:link_id], "Art tag checked"
    assert !tags_for_form[1][:link_id], "News tag not checked"
    assert_equal 'news', tags_for_form[1][:name]
    assert_equal items_id(:art), tags_for_form[0][:id]
  end
  
  def test_out_of_secure
    SuperDummy.connection.execute "UPDATE addresses SET type='SuperDummy' WHERE id IN (3,4);"
    @bob = SuperDummy.find(3)
    @joe = SuperDummy.find(4)
    @bob.employees = [@joe]
    assert @bob.save
    assert_equal @joe.id, @bob.employees[0][:id]
    assert_equal @bob.id, @joe.boss[:id]
  end
end
