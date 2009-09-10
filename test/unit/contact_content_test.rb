require 'test_helper'

class ContactContentTest < Zena::Unit::TestCase
  
  def test_cannot_set_site_id_with_new_record
    login(:tiger)
    cont = ContactContent.new(:site_id => 1234)
    assert_nil cont.site_id
  end
  
  def test_cannot_set_site_id_with_old_record
    login(:tiger)
    cont = contact_contents(:tiger)
    original_site_id = cont.site_id
    cont.update_attributes(:site_id => 1234)
    assert_equal original_site_id, cont.site_id
  end
  
  def test_site_id
    login(:tiger)
    cont = ContactContent.create(:version_id=>versions_id(:tiger_en))
    assert !cont.new_record?, "Not a new record"
    assert_equal sites_id(:zena), cont.site_id
  end
  
  def test_fullname
    assert_equal "Panthera Leo Verneyi", contact_contents(:lion).fullname
  end

 def test_initials
   assert_equal "PLV", contact_contents(:lion).initials
 end
end
