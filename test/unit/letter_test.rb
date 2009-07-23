require File.dirname(__FILE__) + '/../test_helper'

class LetterTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end
  
  def test_split_kpath
    login(:tiger)
    letter = secure!(Node) { nodes(:letter) }
  end
end
