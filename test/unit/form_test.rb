require File.dirname(__FILE__) + '/../test_helper'

class FormTest < Test::Unit::TestCase
  include ZenaTestUnit


  # Replace this with your real tests.
  #def test_parse_data
  #  test_visitor(:ant)
  #  form = secure(Form) { Form.find(nodes_id(:form)) }
  #  assert_kind_of Form, form
  #  assert_equal 12, form.parse("[data, filter=>year=2006]{[sum births]}").to_i
  #  assert_equal 'cat dog', form.parse("[data]{[each animal, join=>' ']{[animal]}}")
  #  result = form.parse("[each animal, table=>true]{[animal][sum births]}")
  #  assert (result =~ /^<table class='form_data'/), "Parsed result is a table"
  #  assert (result =~ /<tr.*class='header'.*<td>animal<\/td><td>sum births<\/td>/), "Parsed result contains the header"
  #  assert (result =~ /<td>cat<\/td><td>13<\/td>.*<td>dog<\/td><td>27<\/td>/m), "Total births for cat is 13, dog is 27, cat before dog"
  #end
  def test_todo
    #false
  end
  
  def test_parser
    #test_visitor(:ant)
    #test_visitor(:ant)
    #form = secure(Form) { Form.find(nodes_id(:form)) }
    #assert_kind_of Form, form
  end
end
