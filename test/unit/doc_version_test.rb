require File.dirname(__FILE__) + '/../test_helper'

class DocVersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    assert_equal "<img src='/images/ext/pdf.png' width='15' height='20' class='tiny'/>", doc.img_tag
    assert_equal "<img src='/images/ext/pdf.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/pdf.png' width='15' height='20' class='std'/>", doc.img_tag('std')
  end
  
  def test_file
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    v = doc.send(:version)
    assert_kind_of DocVersion, v
    assert_equal uploaded_pdf('water.pdf').read, v.file.read
  end
  
  def test_no_file
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    v = doc.send(:version)
    v[:file_ref] = nil
    assert_raise(ActiveRecord::RecordNotFound) { v.file }
  end
  
  def test_filesize
    doc = secure(Item) { items(:water_pdf) }
    assert_equal 29279, doc.send(:version).filesize
  end
  
  # TODO : test before_save, after_...
  
  def test_cannot_set_file_ref
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(Zena::AccessViolation) { version.file_ref = items_id(:lake) }
  end
  
  def test_cannot_set_file_ref_by_attribute
    visitor(:ant)
    item = secure(Item) { Item.find(items_id(:ant))}
    version = item.send(:version)
    assert_raise(Zena::AccessViolation) { version[:file_ref] = items_id(:lake) }
  end
end
