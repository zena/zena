require File.dirname(__FILE__) + '/../test_helper'
require 'nodes_controller'

# Re-raise errors caught by the controller.
class NodesController
  def rescue_action(e); raise e; end
end

class TestNodeController < NodesController
  include NodesHelper
end

class NodesControllerTest < ZenaTestController

  def setup
    super
    @controller = NodesController.new
    init_controller
  end
  
  def test_form_tabs
    @controller = TestNodeController.new
    init_controller
    page = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    @controller.instance_variable_set(:@node, page)
    assert_equal [["drive", "drive"], ["links", "links"], ["help", "help"]], @controller.send(:form_tabs)
  end
  
  def test_popup_page_not_found
    get 'drive', :id=>99
    assert_redirected_to :controller => 'node', :action=>'not_found'
    get 'not_found'
    assert_template 'node/not_found'
  end
  
  def test_get_attributes_from_yaml
    f = Tempfile.new('any.yml')
    path = f.path
    File.open(path, 'w') do |file|
      path = file.path
      file.puts "first: I am the first
five: 5
done: \"I am done\""
    end
    attrs = @controller.send(:get_attributes_from_yaml, path)
    
    assert_equal 'I am the first', attrs['first']
    assert_equal 5,                attrs['five']
    assert_equal 'I am done',      attrs['done']
  end
  
  def test_create_nodes_from_folder
    login(:tiger)
    parent = secure(Project) { Project.create(:name => 'import', :parent_id => nodes_id(:zena)) }
    assert !parent.new_record?, "Not a new record"
    @controller.send(:create_nodes_from_folder, :folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent => parent )
    children = parent.children
    assert_equal 2, children.size
    bird, simple = children
    
    assert_equal 'bird', bird[:name]
    assert_equal 'simple', simple[:name]
    assert_equal 'The sky is blue', simple.v_title
    assert_equal 'jpg', bird.c_ext
  end
  
  def test_import
    
  end
end
