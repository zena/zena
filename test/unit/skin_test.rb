require 'test_helper'

class SkinTest < Zena::Unit::TestCase
  context 'With a writer' do
    setup do
      login(:tiger)
    end

    context 'creating new objects' do
      subject do
        secure(Page) { Page.create(:parent_id => nodes_id(:zena), :title => 'snow') }
      end

      should 'inherit skin_id' do
        assert_equal nodes_id(:default), subject.skin_id
      end
    end # creating new objects

  end # With a writer

end