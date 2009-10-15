require 'test_helper'

class DynDummy < ActiveRecord::Base
  before_save :set_dummy_node_id
  set_table_name 'versions'
  include Zena::Use::DynAttributes::ModelMethods
  dynamic_attributes_setup :nested_alias => {%r{^d_(\w+)} => ['dyn']}

  def set_dummy_node_id
    self[:node_id] = 0
    self[:user_id] = 0
  end
end

class DynStrictDummy < ActiveRecord::Base
  set_table_name 'versions'
  include Zena::Use::DynAttributes::ModelMethods
  dynamic_attributes_setup :only => [:bio, :phone], :nested_alias => {%r{^d_(\w+)} => ['dyn']}

  def before_save
    self[:node_id] = 123
    self[:user_id] = 123
  end
end

class DynSubStrictDummy < DynStrictDummy
end

class DynSub2StrictDummy < DynStrictDummy
  include Zena::Use::DynAttributes::ModelMethods
  dynamic_attributes_setup :only => [:hell]
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

  def test_many_alias_methods
    assert DynDummy.create(:title => 'worn shoes', :text=>'', :comment=>'', :summary=>'', :d_color=>'blue', :d_life=>'fun', :d_shoes=>'worn')
    record = DynDummy.find_by_title('worn shoes')
    assert_equal 'worn', record.dyn.send('shoes')
    assert_equal 'worn', record.dyn['shoes']
    assert_equal 'blue', record.dyn.send('color')
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
    assert_equal 'Martin', record.dyn['heidegger']
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
    record.dyn['hell'] = 'lucifer'
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
    assert_equal 'me', record2.dyn['lobotomize']

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
    assert_nil record2.dyn['lobotomize']
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
    assert_equal 'hurt', record.dyn['fingers']
  end

  def test_delete
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_life=>'fun', :d_joy=>'weird')
    assert_equal 'weird', record.dyn.delete(:joy)
    assert_nil record.dyn['joy']
    assert record.save
    record = DynDummy.find(record[:id]) # reload
    assert_nil record.dyn['joy']
    assert_equal 'fun', record.dyn['life']
  end

  def test_destroy
    assert record  = DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_life=>'fun', :d_joy=>'weird')
    assert_equal 2, DynDummy.count_by_sql("SELECT COUNT(*) FROM dyn_attributes WHERE owner_id = #{record[:id]}")
    assert record.destroy
    assert_equal 0, DynDummy.count_by_sql("SELECT COUNT(*) FROM dyn_attributes WHERE owner_id = #{record[:id]}")
  end

  def test_empty_key_empty_value
    assert_raise(ActiveRecord::UnknownAttributeError)  { DynDummy.create(:title => 'lolipop', :text=>'', :comment=>'', :summary=>'', :d_=>'bad', :d_og=>'') }
  end

  def test_would_edit
   record = DynDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'', :d_bio=>'biography', :d_hell => 'blind love')
   assert !record.dyn.would_edit?('hell' => 'blind love', 'bio' => 'biography')
   assert  record.dyn.would_edit?('hell' => 'blind love', 'bio' => '')
   assert  record.dyn.would_edit?('hell' => 'blind love', 'fox' => 'hop')
   assert !record.dyn.would_edit?('hell' => 'blind love', 'fox' => '', 'fly' => nil)
  end

  def test_changed
    record = DynDummy.create(:title => 'this is my title', :text=>'', :comment=>'', :summary=>'', :d_bio=>'biography', :d_hell => 'blind love')
    record = DynDummy.find(record.id) # reload
    dyn = record.dyn
    assert !dyn.changed?
    dyn['bio'] = 'biography'
    assert !dyn.changed?
    dyn['bio'] = 'Gemüse'
    assert dyn.changed?

    record = DynDummy.find(record.id) # reload
    dyn = record.dyn

    dyn['title'] = nil
    assert dyn.changed?
  end
end