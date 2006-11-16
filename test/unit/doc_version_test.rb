require File.dirname(__FILE__) + '/../test_helper'

class DocVersionTest < Test::Unit::TestCase
  include ZenaTestUnit

  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Document) { Document.find( items_id(:water_pdf) ) }
    assert_equal "<img src='/images/ext/pdf.png' width='15' height='20' class='tiny'/>", doc.img_tag
    assert_equal "<img src='/images/ext/pdf.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/pdf.png' width='15' height='20' class='std'/>", doc.img_tag('std')
    doc = secure(Document) { Document.find( items_id(:bird_jpg) ) }
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag
    assert_equal "<img src='/data/jpg/20/bird.jpg' width='661' height='600'/>", doc.img_tag('pv')
  end
  
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
