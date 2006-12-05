require File.dirname(__FILE__) + '/../test_helper'
require 'note_controller'

# Re-raise errors caught by the controller.
class NoteController; def rescue_action(e) raise e end; end

class NoteControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    @controller = NoteController.new
    init_controller
  end
  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
