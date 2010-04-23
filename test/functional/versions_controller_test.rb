require 'test_helper'

class VersionsControllerTest < Zena::Controller::TestCase

  def version_hash(version_ref, number = nil)
    version = versions(version_ref)
    number ||= version.number
    {:id => number, :node_id => version.node.zip}
  end

  context 'A visitor without write access' do
    setup do
      login(:anon)
    end

    should 'receive a missing response when getting a version' do
      get 'show', version_hash(:lake_en)
      assert_response :missing
    end
  end

  context 'A visitor with write access' do
    setup do
      login(:ant)
    end

    should 'get a page rendered with zafu when getting a version' do
      get 'show', version_hash(:lake_red_en)
      assert_response :success
      assert_match %r{default/Node/fr/_main.erb$}, @response.rendered[:template].to_s
    end
  end

  context 'A visitor with drive access' do
    setup do
      login(:lion)
      @node = secure!(Node) { nodes(:status) }
    end

    context 'on a node with removed versions and data' do
      setup do
        put 'remove', :node_id => @node.zip, :id => 1
        put 'remove', :node_id => @node.zip, :id => 2
      end

      should 'get an ajax replace and see a warning on version destroy' do
        assert_difference('Version.count', -1) do
          delete 'destroy', :node_id => @node.zip, :id => 1, :drive => true, :format => 'js'
        end
        assert_match %r{Element\.replace\(.versions},  @response.body
        assert_match %r{This node contains sub-nodes}, @response.body
      end
    end
  end

  def test_can_edit
    # make :anon a user (so she can access the versions)
    User.connection.execute "UPDATE users SET status = #{User::Status[:user]} WHERE id = #{users_id(:anon)}"
    login(:anon)
    get 'edit', version_hash(:wiki_en)
    assert_response :success
    assert_match %r{wikiSkin/Node-\+popupLayout/en/_main$}, @response.layout
    login(:ant)
    get 'edit', version_hash(:status_en, 0)
    assert_match "form[@action='/nodes/#{nodes_zip(:status)}']"
    get 'edit', version_hash(:lake_red_en)
    assert_match "form[@action='/nodes/#{nodes_zip(:lake)}']"
  end

  def test_parse_assets
    login(:lion)
    node = secure!(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    b_at = bird.updated_at
    assert bird.update_attributes(:parent_id => node[:parent_id])
    Zena::Db.set_attribute(bird, :updated_at, b_at)
    start =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('bird.jpg') }
    #footer { background:url('/projects/wiki/flower.jpg') }
    END_CSS

    assert node.update_attributes(:text => start.dup)
    get 'edit', :node_id => node.zip, :id => 0, :parse_assets => 'true'
    assert_response :success
    version = assigns(:node).version

    res =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('/en/image30.jpg?1144713600') }
    #footer { background:url('/en/image31.jpg?1144713600') }
    END_CSS
    assert_equal res, text
    get 'edit', :node_id => node.zip, :id => 0, :unparse_assets => 'true'
    assert_response :success
    version = assigns(:node).version
    assert_equal start, text
  end
end
