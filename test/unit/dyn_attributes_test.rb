require File.dirname(__FILE__) + '/../test_helper'
class DynDummy < ActiveRecord::Base
  set_table_name 'versions'
  uses_dynamic_attributes
end

class DynStrictDummy < ActiveRecord::Base
  set_table_name 'versions'
  uses_dynamic_attributes :only => [:bio, :phone]
end

class DynSubStrictDummy < DynStrictDummy
end

class DynSub2StrictDummy < DynStrictDummy
  uses_dynamic_attributes :only => [:hell]
end

class AttrDummy < ActiveRecord::Base
  set_table_name 'dyn_attributes'
end

class DynAttributesTest < Test::Unit::TestCase
  
  def test_simple
    assert record = DynDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'')
    assert_nil record.dyn['color']
    record.dyn['color'] = 'blue'
    assert_equal 'blue', record.dyn['color']
    assert_equal 'blue', record.dyn[:color]
    assert record.save
    
    record = DynDummy.find(record[:id]) # reload
    assert_equal 'blue', record.dyn['color']
  end
  
  def test_many_pseudo_methods
    assert DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    record = DynDummy.find_by_title('lolipop')
    assert_equal 'worn', record.d_shoes
    assert_equal 'worn', record.dyn['shoes']
    assert_equal 'blue', record.d_color
  end
  
  def test_update
    assert record = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    
    assert_equal 'blue', record.dyn['color'] # reload hash
    proxy = record.dyn
    keys = proxy.instance_variable_get(:@keys)
    assert keys['color']
    assert keys['shoes']
    assert keys['life']
    
    assert record.update_attributes(:d_life => 'hell', :d_heidegger => 'Martin')
    proxy = record.dyn
    new_keys = proxy.instance_variable_get(:@keys)
    ['color', 'life', 'shoes'].each do |k|
      assert_equal keys[k], new_keys[k]
    end
    assert_equal 'Martin', record.d_heidegger
  end
  
  def test_delete
    assert record = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    proxy = record.dyn
    keys = proxy.instance_variable_get(:@keys)
    assert record.update_attributes(:d_life => nil)
    assert_nil record.dyn['life']
    assert_nil AttrDummy.find_by_id(keys['life'])
  end
  
  def test_delete_many
    assert record = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    proxy = record.dyn
    keys = proxy.instance_variable_get(:@keys)
    assert record.update_attributes(:d_life => nil, :d_shoes => nil)
    assert_nil record.dyn['life']
    assert_nil AttrDummy.find_by_id(keys['life'])
    assert_nil record.dyn['shoes']
    assert_nil AttrDummy.find_by_id(keys['shoes'])
  end
  
  # DynStrictDummy
  
  def test_only
    assert record = DynStrictDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'', :d_bio=>'biography', :d_hell => 'not allowed')
    assert_equal 'biography', record.dyn['bio']
    assert_nil record.dyn['hell']
    record.d_hell = 'lucifer'
    record.dyn['hell'] = 'master of darkness'
    assert record.save
    assert_nil record.dyn['hell']
  end
  
  def test_only_subclass
    assert record = DynSubStrictDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'', :d_bio=>'biography', :d_hell => 'not allowed')
    assert_equal 'biography', record.dyn['bio']
    assert_nil record.dyn['hell']
  end
  
  def test_only_subclass_overwrite
    assert record = DynSub2StrictDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'', :d_bio=>'biography', :d_hell => 'not allowed')
    assert_nil record.dyn['bio']
    assert_equal 'not allowed', record.dyn['hell']
  end
  
  def test_each
    assert record = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    record.dyn.each do |k,v|
      case k
      when 'color'
        assert_equal 'blue', v
      when 'life'
        assert_equal 'fun', v
      when 'shoes'
        assert_equal 'worn', v
      end
    end
  end

  def test_dyn_equal
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    proxy = record.dyn
    keys = proxy.instance_variable_get(:@keys)
    assert record2 = DynDummy.create(:title => 'hulk', :text=>'', :comment=>'', :summary=>'', :d_lobotomize=>'me')
    assert_equal 'me', record2.d_lobotomize
    
    record2.dyn = record.dyn
    assert record2.save, "Can save modified record"
    
    record2 = DynDummy.find(record2[:id]) # reload
    proxy = record2.dyn
    new_keys = proxy.instance_variable_get(:@keys)
    assert_equal 'blue', record2.dyn['color']
    keys.each do |k,id|
      assert new_keys[k]
      assert_not_equal id, new_keys[k]
    end
    assert_nil record2.d_lobotomize
  end
  
  def test_dyn_update_with
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    proxy = record.dyn
    keys = proxy.instance_variable_get(:@keys)
    
    record.dyn = {:color => 'yellow', :lobotomize=>'me'}
    assert record.save, "Can save modified record"
    
    record = DynDummy.find(record[:id]) # reload
    proxy = record.dyn
    new_keys = proxy.instance_variable_get(:@keys)
    assert_equal 'yellow', record.dyn['color']
    assert_equal 'me', record.dyn['lobotomize']
    assert_nil record.dyn['life']
    assert_nil record.dyn['shoes']
  end
  
  def test_set_with_hash
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'')
    record.dyn = {:fingers => 'hurt'}
    assert record.save, "Can save"
    
    record = DynDummy.find(record[:id]) # reload
    assert_equal 'hurt', record.d_fingers
  end
  
  def test_delete
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_life=>'fun', :d_joy=>'weird')
    assert_equal 'weird', record.dyn.delete(:joy)
    assert_nil record.d_joy
    assert record.save
    record = DynDummy.find(record[:id]) # reload
    assert_nil record.d_joy
    assert_equal 'fun', record.d_life
  end
  
  
  def test_empty_key_empty_value
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_=>'bad', :d_og=>'')
    assert !record.new_record?
    assert_nil record.d_
    assert_nil record.d_og
    assert_nil record.dyn['']
  end
end