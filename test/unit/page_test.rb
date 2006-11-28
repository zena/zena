require File.dirname(__FILE__) + '/../test_helper'
require 'document' # this is needed to load the document model.
require 'tag'
require 'project'
require 'tracker'
require 'contact'

class PageTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_select_classes
    assert_equal ["Page", "Contact", "Project", "Tag", "Tracker"], Page.select_classes
  end
end
