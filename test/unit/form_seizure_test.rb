require File.dirname(__FILE__) + '/../test_helper'

class FormSeizureTest < UnitTestCase
  fixtures :form_seizures, :items, :form_lines

  def test_find_dogs
    visitor(:ant)
    seizures = FormSeizure.find_seizures(items_id(:form), 'animal=dog', user_groups)
    assert_equal 6, seizures.size
  end
  
  def test_access_values
    seizure = FormSeizure.find(1)
    assert_equal 'dog', seizure['animal']
    assert_equal '2005', seizure['year']
    assert_equal '1', seizure['births']
  end
end
