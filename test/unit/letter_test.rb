require File.dirname(__FILE__) + '/../test_helper'

class LetterTest < ZenaTestUnit
  
  def test_split_kpath
    login(:tiger)
    letter = secure(Node) { nodes(:letter) }
  end
end
