require 'test_helper'
require 'virtual_classes_controller'

# Re-raise errors caught by the controller.
class VirtualClassesController; def rescue_action(e) raise e end; end

class VirtualClassesControllerTest < ZenaTestController
  
  def setup
    super
    @controller = VirtualClassesController.new
    init_controller
  end

  def test_update_superclass
    login(:lion)
    vclass = virtual_classes(:Post)
    assert_equal Note, vclass.superclass
    put 'update', :id => vclass[:id], :virtual_class => {'superclass' => 'Project', 'name' => 'Post'}
    vclass = assigns(:virtual_class)
    assert_equal Project, vclass.superclass
    assert_equal "NPPP", vclass.kpath
  end
end