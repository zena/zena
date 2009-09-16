require 'test_helper'

class ZafuTest < Zena::View::TestCase
  include Zena::Use::Zafu::ViewMethods
  include Zena::Use::Zafu::ControllerMethods

  def test_page_numbers
    s = ""
    page_numbers(2, 3, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "1,2,3", s
    s = ""
    page_numbers(2, 30, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "1,2,3,4,5,6,7,8,9,10", s
    s = ""
    page_numbers(14, 30, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "10,11,12,13,14,15,16,17,18,19", s
    s = ""
    page_numbers(28, 30, ' | ') {|p,j| s << "#{j}#{p}"}
    assert_equal "21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30", s
  end
end