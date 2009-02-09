require File.dirname(__FILE__) + '/../test_helper'

class ContactContentTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  
  def test_cannot_set_site_id
    login(:tiger)
    cont = contact_contents(:tiger)
    assert_raise(Zena::AccessViolation) { cont.site_id = sites_id(:ocean) }
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
