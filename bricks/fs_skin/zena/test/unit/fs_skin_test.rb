require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class Fs_skinTest < Zena::Unit::TestCase

  context 'A Skin' do
    setup do
      login(:lion)
    end

    subject do
      secure(Node) { nodes(:wikiSkin) }
    end

    should 'have z_fs_skin prop' do
      subject.z_fs_skin = 'foo'
      assert_equal 'foo', subject.prop['z_fs_skin']
    end

    should 'allow brick-skin values' do
      assert subject.update_attributes(:z_fs_skin => 'fs_skin-blog')
    end

    should 'allow nil values' do
      assert subject.update_attributes(:z_fs_skin => 'fs_skin-blog')
      assert subject.update_attributes(:z_fs_skin => nil)
    end

    should 'not allow any value' do
      assert !subject.update_attributes(:z_fs_skin => '../foo-/bar/..')
      assert_equal 'invalid', subject.errors[:z_fs_skin]
    end
  end # A Skin
end