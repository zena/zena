require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class StaticIntegrationTest < Zena::Integration::TestCase

  context 'A page using a static Skin' do
    subject do
      secure(Node) { nodes(:wiki) }
    end

    setup do
      $_test_site = 'zena'
      login(:lion)
      skin = secure(Skin) { Skin.create(:title => 'foo', :z_static => 'static-blog', :parent_id => nodes_id(:skins), :v_status => Zena::Status::Pub)}
      subject.skin_id = skin.id
      assert subject.save
    end

    context 'on zafu rebuild' do
      setup do
        FileUtils.rmtree("#{SITES_ROOT}/test.host/zafu")
      end

      should 'use static template' do
        get "http://test.host/en/blog#{subject.zip}.html"
        assert_response :success
        assert_match %r{Copyright <a href="#">Static blog</a>}, response.body
      end
    end # with normal access
  end # A page using a static Skin
end