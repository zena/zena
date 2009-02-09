require File.dirname(__FILE__) + '/../test_helper'

class LetterTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  
  def test_split_kpath
    login(:tiger)
    letter = secure!(Node) { nodes(:letter) }
  end
end
