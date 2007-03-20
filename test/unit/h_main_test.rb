require File.dirname(__FILE__) + '/../test_helper'

class MainHelperTest < ZenaTestHelper
  include MainHelper

  def setup
    @controllerClass = MainController
    super
  end
  
  def test_truth
    assert true
  end
end
  
  