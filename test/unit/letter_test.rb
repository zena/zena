require 'test_helper'

class LetterTest < Zena::Unit::TestCase
  
  def test_split_kpath
    login(:tiger)
    letter = secure!(Node) { nodes(:letter) }
  end
end
