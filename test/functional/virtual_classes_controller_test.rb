require 'test_helper'

class VirtualClassesControllerTest < Zena::Controller::TestCase

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