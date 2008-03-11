=begin
require File.dirname(__FILE__) + '/../test_helper'
require 'preferences_controller'

# Re-raise errors caught by the controller.
class PreferencesController; def rescue_action(e) raise e end; end

class PreferencesControllerTest < ZenaTestController
  
  def setup
    super
    @controller = PreferencesController.new
    init_controller
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
=end