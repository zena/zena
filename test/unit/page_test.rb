require File.dirname(__FILE__) + '/../test_helper'
require 'document' # this is needed to load the document model.
require 'tag'

class PageTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_select_classes
    assert_equal ["Page", "Tag"], Page.select_classes
  end
end
