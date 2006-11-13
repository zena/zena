require File.dirname(__FILE__) + '/../test_helper'
require 'document' # this is needed to load the document model.
require 'Tag'

class PageTest < Test::Unit::TestCase
  include ZenaTestUnit
  def test_truth
    assert true
  end
end
