require File.dirname(__FILE__) + '/../test_helper'

class MainHelperTest < Test::Unit::TestCase

  include ZenaTestHelper
  include ApplicationHelper
  include MainHelper

  def test_check_lang_same
    session[:lang] = 'en'
    obj = nodes(:zena)
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    session[:lang] = 'io'
    obj = nodes(:zena)
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_change_lang
    assert_equal ({:overwrite_params=>{:prefix=>'io'}}), change_lang('io')
    login(:ant)
    assert_equal ({:overwrite_params=>{:lang=>'io'}}), change_lang('io')
  end
  
  def test_title_partial
    @node = secure(Node) { nodes(:tiger) }
    assert_equal 'contact/title', title_partial
    @node = secure(Node) { nodes(:tracker) }
    assert_equal 'main/title', title_partial
    @node = secure(Node) { nodes(:bird_jpg)}
    assert_equal 'document/title', title_partial
  end
  
  def test_edit_button_for_public
    @node = secure(Node) { nodes(:cleanWater) }
    assert !@node.can_edit?, "Node cannot be edited by the public"
    res = edit_button(:all)
    assert_equal '', res
  end
  
  def test_edit_button_wiki_public
    @node = secure(Node) { nodes(:wiki) } 
    assert @node.can_edit?, "Node can be edited by the public"
    res = edit_button(:all)
    assert_match %r{/z/version/edit/19}, res
    assert_match %r{/z/node/drive\?.*version_id=19}, res
  end
  
  def test_node_actions_for_ant
    login(:ant)
    @node = secure(Node) { Node.find(nodes_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match    %r{/z/version/edit}, res
    assert_no_match %r{/z/node/drive}, res
  end
  
  def test_node_actions_for_tiger
    login(:tiger)
    @node = secure(Node) { Node.find(nodes_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/node/drive}, res
    @node.edit!
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/version/propose}, res
    assert_match %r{/z/version/publish}, res
    assert_match %r{/z/node/drive}, res
    @node.save
    login(:ant)
    session[:lang] = 'fr'
    @node = secure(Node) { Node.find(nodes_id(:cleanWater)) }
    res = edit_button(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/node/drive}, res
    session[:lang] = 'en'
    @node = secure(Node) { Node.find(nodes_id(:cleanWater)) }
    res = edit_button(:all)
    assert_no_match %r{/z/version/edit}, res
    assert_no_match %r{/z/node/drive}, res
  end
  
  def test_traductions
    session[:lang] = 'en'
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'main', :action=>'index'} ) }
    @node = secure(Node) { Node.find(nodes_id(:status)) } # en,fr
    trad = traductions
    assert_equal 2, trad.size
    assert_match /class='on'.*href="\/en"/, trad[0]
    assert_no_match /class='on'/, trad[1]
    @node = secure(Node) { Node.find(nodes_id(:cleanWater)) } #  en
    trad = traductions
    assert_equal 1, trad.size
    session[:lang] = 'io'
    trad = traductions
    assert_equal 2, trad.size
    assert_match /class='off'/, trad[1]
  end
  
  def test_author
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'main', :action=>'index'} ) }
    @node = Node.find(nodes_id(:projects))
    session[:lang] = 'en'
    assert_match /class='info'.*posted by.*Panther Tigris Sumatran.*on 04.11.*Traductions :/m , author(:large)
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author(:small)
    @node = secure(Node) { Node.find(nodes_id(:opening)) }
    assert_equal users_id(:tiger), @node.v_author[:id]
    assert_match /class='info'.*posted by.*Panther Tigris Sumatran/m, author(:large)
    assert_equal "<div class='info'><b>PTS</b> - 04.11</div>", author
    session[:lang] = 'fr'
    @node = secure(Node) { Node.find(nodes_id(:opening)) }
    assert_equal users_id(:ant), @node.v_author[:id]
    assert_match /class='info'.*original by.*Panther Tigris Sumatran.*new post by.*Solenopsis Invicta/m, author(:large)
    assert_equal "<div class='info'><b>SI</b> - 11.04</div>", author
  end
  
  def test_path_links_root
    @node = secure(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<ul id='path' class='path'><li><a href='/en'>zena</a></li></ul>", path_links
    node2 = @node
    @node = secure(Node) { Node.find(nodes_id(:status))}
    assert_equal "<ul class='path'><li><a href='/en'>zena</a></li></ul>", path_links(node2)
  end
  
  def test_path_links_root_with_login
    login(:ant)
    @node = secure(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<ul id='path' class='path'><li><a href='/#{AUTHENTICATED_PREFIX}'>zena</a></li></ul>", path_links
  end
  
  def test_path_links_page
    @node = secure(Node) { Node.find(nodes_id(:cleanWater))}
    assert_match %r{<ul id='path'.*href='/en'>zena.*href='/en/projects'>projects.*href='/en/projects/cleanWater'>cleanWater}, path_links
  end
  
  def test_admin_link_translation
    assert_equal '', admin_link(:translation)
    login(:lion)
    assert_match %r{Translate interface.*z/trans/list.*\?translate=on}, admin_link(:translation)
    session[:translate] = true
    assert_match %r{Translate interface.*z/trans/list.*\?translate=off}, admin_link(:translation)
  end

  def test_lang_links
    login(:lion)
    @request = ActionController::TestRequest.new
    @request.instance_eval{ @parameters = {:controller=>'main', :action=>'show', :path=>'projects/cleanWater', :prefix=>AUTHENTICATED_PREFIX}}
    class << self
      def request
        @request
      end
    end
    assert_match %r{id='lang'.*span.*b.*en.*href=.*/oo/projects/cleanWater\?lang=es.*es.*fr.*}, lang_links
    session[:translate] = true
    assert_match %r{id='lang'.*span.*b.*en.*href=.*/oo/projects/cleanWater\?lang=es.*es.*fr.*z/trans/list.*translate=off}, lang_links
    class << self
      remove_method(:request)
    end
    remove_instance_variable :@request
  end
  
  def test_lang_links_no_login
    @request = ActionController::TestRequest.new
    @request.instance_eval{ @parameters = {:controller=>'main', :action=>'show', :path=>'projects/cleanWater', :prefix=>AUTHENTICATED_PREFIX}}
    class << self
      def request
        @request
      end
    end
    assert_match %r{id='lang'.*span.*b.*en.*href=.*/es/projects/cleanWater.*es.*/fr/projects/cleanWater.*fr.*}, lang_links
    class << self
      remove_method(:request)
    end
    remove_instance_variable :@request
  end
  
  def test_lang_ajax_link
    login(:lion)
    assert_match %r{<div id='lang'><span>.*new Ajax.Update.*/z/trans/lang_menu}, lang_ajax_link
    session[:translate] = true
    assert_match %r{<div id='lang'><span>.*new Ajax.Update.*/z/trans/lang_menu.*translate=off}, lang_ajax_link
  end
  
end
  
  