require 'test_helper'

class NodesControllerCommitTest < ActionController::TestCase
  self.use_transactional_fixtures = false
  include Zena::Use::TestHelper

  tests NodesController

  def test_import_xhtml
    login(:tiger)

    if defined?(@controller)
      @controller.class_eval do
        def set_visitor
          # do nothing
        end
      end
    end

    without_files('/test.host/data') do
      without_files('/test.host/zafu') do
        post 'import', :id => nodes(:zena_skins).zip, :node => {:klass => 'Skin', :v_status => Zena::Status[:pub]}, :attachment => uploaded_archive('jet_30.zip')

        node_list = assigns(:nodes)
        nodes = {}
        node_list.each do |n|
          nodes[n.node_name] = n
        end
        assert skin = nodes['jet30']
        assert_kind_of Skin, skin
        assert zafu = nodes['Node']
        assert_kind_of Template, zafu
        assert_equal 'html', zafu.format
        assert_equal 'Node', zafu.target_klass
        assert_equal 'N', zafu.tkpath
        assert style = nodes['style']
        assert_kind_of TextDocument, style
        assert navBar = nodes['navBar']
        assert_kind_of Image, navBar
        assert xhtmlBgHover = nodes['xhtmlBgHover']
        assert_kind_of Image, xhtmlBgHover
        assert topIcon = nodes['topIcon']
        assert_kind_of Image, topIcon
        ['lftPic1', 'lftPic2', 'lftPic3'].each do |p|
          assert nodes[p]
          assert_kind_of Image, nodes[p]
        end
        assert_match %r{#header ul\{\s*background:url\('/en/image#{navBar.zip}.gif\?#{navBar.updated_at.to_i}'\)}m, style.text
        assert_match %r{a\.xht:hover\{\s*background:url\('/en/image#{xhtmlBgHover.zip}.gif\?#{xhtmlBgHover.updated_at.to_i}'\)}, style.text

        # use this template
        status = nodes(:zena_status)
        status.visitor = Thread.current[:visitor]
        assert status.update_attributes(:skin_id => skin.id, :inherit => 0)
        get 'show', 'prefix'=>'oo', 'path'=>['projects', 'cleanWater', "page#{status.zip}.html"]
        assert_response :success

        assert_match %r{posuere eleifend arcu</p>\s*<img [^>]*src\s*=\s*./en/image#{topIcon.zip}.gif}, @response.body
      end
    end
  end
end