require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class StaticTest < Zena::Unit::TestCase

  context 'A Skin' do
    setup do
      login(:lion)
    end

    subject do
      secure(Node) { nodes(:wikiSkin) }
    end

    should 'have z_static prop' do
      subject.z_static = 'foo'
      assert_equal 'foo', subject.prop['z_static']
    end

    should 'allow brick-skin values' do
      assert subject.update_attributes(:z_static => 'static-blog')
    end

    should 'allow nil values' do
      assert subject.update_attributes(:z_static => 'static-blog')
      assert subject.update_attributes(:z_static => nil)
    end

    should 'not allow any value' do
      assert !subject.update_attributes(:z_static => '../foo-/bar/..')
      assert_equal 'invalid', subject.errors[:z_static]
    end
  end # A Skin
end