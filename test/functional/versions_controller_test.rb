require 'test_helper'

class VersionsControllerTest < Zena::Controller::TestCase

  def version_hash(version_ref, number = nil)
    version = versions(version_ref)
    number ||= version.number
    {:id => number, :node_id => version.node.zip}
  end

  def test_show
    test_site('zena')
    v = versions(:lake_red_en)
    get 'show', version_hash(:lake_red_en)
    assert_redirected_to version_hash(:lake_en)
    login(:ant)
    get 'show', version_hash(:lake_red_en)
    assert_response :success
    assert_match %r{default/Node/fr/_main.erb$}, @response.rendered[:template].to_s
  end

  def test_can_edit
    # make :anon a user (so she can access the versions)
    Participation.connection.execute "UPDATE participations SET status = #{User::Status[:user]} WHERE user_id = #{users_id(:anon)} AND site_id = #{sites_id(:zena)}"
    login(:anon)
    get 'edit', version_hash(:wiki_en)
    assert_response :success
    assert_match %r{wikiSkin/Node-\+popupLayout/en/_main$}, @response.layout
    login(:ant)
    get 'edit', version_hash(:status_en, 0)
    assert_css "form[@action='/nodes/#{nodes_zip(:status)}']"
    get 'edit', version_hash(:lake_red_en)
    assert_css "form[@action='/nodes/#{nodes_zip(:lake)}']"
  end

  def test_cannot_edit
    login(:anon)
    get 'edit', version_hash(:status_en)
    assert_response :missing
    get 'edit', version_hash(:status_en, 0)
    assert_response :missing
  end

=begin

  def test_preview
    login(:tiger)
    post 'preview', :node=>{ :id=>nodes_id(:status), :v_title=>'my super goofy new title' }
    assert_rjs_tag :rjs => {:block => 'title' }, :content=>"my super goofy new title"
  end

  def test_can_save
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    assert_response :success
    assert_no_tag :tag=>'div', :attributes=>{:id=>'error'}
    node = secure!(Node) { nodes(:status) }
    assert_equal 'I am a new title', node.v_title
  end

  def test_cannot_save
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    assert_redirected_to '404'
    assert_equal 'status title', secure!(Node) { nodes(:status) }.v_title
  end

  def test_can_propose
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:red], node.v_status
    post 'propose', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:prop], secure!(Node) { Node.version(node.v_id) }.v_status
  end

  def test_cannot_propose
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:red], node.v_status
    login(:tiger)
    post 'propose', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:red], secure!(Node) { Node.version(node.v_id) }.v_status
  end

  def test_can_refuse
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:tiger)
    post 'refuse', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:red], Version.find(node.v_id).status
  end

  def test_cannot_refuse
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:ant)
    post 'refuse', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:prop], Version.find(node.v_id).status
  end

  def test_can_publish
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:tiger)
    post 'publish', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  end

  def test_cannot_publish
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:ant)
    post 'publish', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:prop], Version.find(node.v_id).status
  end

  def test_can_remove
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'publish', :id=>node.v_id
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
    post 'remove', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:rem], Version.find(node.v_id).status
  end

  def test_cannot_remove
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure!(Node) { nodes(:status) }
    post 'publish', :id=>node.v_id
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
    login(:ant)
    post 'remove', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  end

  def test_can_unpublish_many_versions
    Node.connection.execute("UPDATE versions SET user_id=4 WHERE id IN (12,30)")
    # status : version 30(fr) = pub, version 12(en) = pub
    login(:tiger)
    session[:lang] = 'fr'
    node = secure!(Node) { nodes(:status) }
    assert_equal 'fr', node.v_lang
    assert node.unpublish, "Can unpublish french version."
    assert_equal Zena::Status[:red], node.v_status

    # BUG when two version (fr,en). fr = red, en = pub. removing
    # fr we cannot 'unpublish' en. Reload of drive popup => now we can !!?
    node = secure!(Node) { nodes(:status) }
    post 'remove', :id=>versions_id(:status_fr), :drive=>true
    assert_response :success
    assert_no_match %r{Could not remove plublication}m, response.body
    post 'unpublish', :id=>versions_id(:status_en), :drive=>true
    assert_response :success
    assert_no_match %r{Could not}m, response.body
  end

  def test_form_tabs
    print 'P'
#    @controller = HelperVersionController.new
#    init_controller
#    page     = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
#    contact  = @controller.send(:secure, Node) { Node.find(nodes_id(:lake)) }
#    @controller.instance_variable_set(:@node, page)
#    assert_equal [["text", "text"], ["title", "title"], ["help", "help"]], @controller.send(:form_tabs)
#    @controller.instance_variable_set(:@node, contact)
#    assert_equal [["text", "text"], ["title", "title"], ["contact", "any_contact"], ["help", "help"]], @controller.send(:form_tabs)
  end

  def test_backup
    without_files('data/test/jpg') do
      login(:ant)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy',
                                          :v_title=>'Bird nest',
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert_kind_of Image , img
      assert ! img.new_record? , "Not a new record"
      assert_equal 'Bird nest', img.v_title
      version_id = img.v_id

      # backup (and try to fool with post data)
      get 'backup', :id=>img.v_id, :node=>{ :v_title=>'funky', :crop=>{:x=>'10',:y=>'10',:w=>'20',:h=>'20'}}
      version = Version.find(version_id)
      assert_equal 'Bird nest', version[:title]

      assert_equal 660, img.version.content.width
      assert_equal 600, img.version.content.height
      assert_equal 56183, img.version.content.size
    end
  end

  def test_change_bad_file_format
    without_files('data/test') do
      login(:tiger)
      img = secure!(Image) { Image.create( :parent_id=>nodes_id(:cleanWater),
                                          :inherit => 1,
                                          :name=>'birdy',
                                          :v_title=>'Bird nest',
                                          :c_file => uploaded_jpg('bird.jpg')) }
      assert_kind_of Image , img
      assert ! img.new_record? , "Not a new record"
      assert_equal 'Bird nest', img.v_title
      version_id = img.v_id

      # backup (and try to fool with post data)
      post 'save', :node=>{:id=>img[:id], :c_file=>uploaded_text('some.txt') }
      assert_response :success
      img = secure!(Node) { Node.find(img[:id]) }
      assert_equal 56183, img.version.content.size
    end
  end

  # def test_can_redit
  #   login(:tiger)
  #   post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
  #   node = secure!(Node) { nodes(:status) }
  #   post 'publish', :id=>node.v_id
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  #   post 'redit', :id=>node.v_id
  #   assert_redirected_to "/z/version/show/#{node.v_id}"
  #   assert_equal Zena::Status[:red], Version.find(node.v_id).status
  # end
  #
  # def test_cannot_redit
  #   login(:tiger)
  #   post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
  #   node = secure!(Node) { nodes(:status) }
  #   post 'publish', :id=>node.v_id
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  #   login(:ant)
  #   post 'redit', :id=>node.v_id
  #   assert_redirected_to '404'
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  # end
=end
end
