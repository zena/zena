require File.dirname(__FILE__) + '/../test_helper'

class DocVersionTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_img_tag
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    assert_equal "<img src='/images/ext/pdf.png' width='32' height='32' class='tiny'/>", doc.img_tag
    assert_equal "<img src='/images/ext/pdf-pv.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/pdf-std.png' width='32' height='32' class='std'/>", doc.img_tag('std')
  end
  
  def test_img_tag_other
    visitor(:tiger)
    doc = secure(Item) { items(:water_pdf) }
    doc.name = 'water.bin'
    puts "DOC :#{doc.object_id}"
    assert_equal 'bin', doc.ext
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' class='tiny'/>", doc.img_tag
    assert_equal "<img src='/images/ext/other-pv.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/other-std.png' width='32' height='32' class='std'/>", doc.img_tag('std')
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
    assert_nil v.file
  end
  
  def test_filesize
    doc = secure(Item) { items(:water_pdf) }
    assert_equal 29279, doc.send(:version).filesize
  end
  
  def test_cannot_set_file_ref
    visitor(:ant)
    item = secure(Item) { items(:water_pdf) }
    version = item.send(:version)
    assert_raise(Zena::AccessViolation) { version.file_ref = items_id(:lake) }
  end
  
  def test_can_set_file_ref_by_attribute
    visitor(:ant)
    item = secure(Item) { items(:ant) }
    version = item.send(:version)
    assert_nothing_raised(Zena::AccessViolation) { version[:file_ref] = items_id(:lake) }
  end
  
  def test_title
    visitor(:ant)
    item = secure(Item) { items(:water_pdf) }
    v = item.send(:version)
    assert_equal "", v[:title]
    assert_equal "water.pdf", item[:name]
    assert_equal "water", v.title
    v[:title] = 'lac leman'
    assert_equal 'lac leman', v.title
  end
  
  def test_has_file
    visitor(:ant)
    doc = DocVersion.new
    assert ! doc.save, 'Cannot save'
    assert_equal 'not set', doc.errors[:file]
  end
  
  def test_update_file_ref_one_version
    preserving_files("/data/test/pdf/36") do
      visitor(:ant)
      set_lang('en')
      item = secure(Item) { items(:forest_pdf) }
      assert_equal Zena::Status[:red], item.v_status
      dv = item.send(:version)
      assert_equal versions_id(:forest_red_en), dv[:file_ref]
      #assert_equal dv.file.read, uploaded_pdf('forest.pdf').read
      assert_kind_of DocFile, dv.file
      assert_equal 63569, dv.file.size
      assert item.update_redaction(:file=>uploaded_pdf('water.pdf')), 'Can edit item'
      dv = item.send(:version)
      assert_equal versions_id(:forest_red_en), dv[:file_ref]
      assert_equal 29279, dv.file.size
      assert_equal dv.file.read, uploaded_pdf('water.pdf').read
    end
  end
  
  def test_cannot_change_file_if_many_uses
    preserving_files("/data/test/pdf") do
      visitor(:ant)
      set_lang('fr')
      item = secure(Item) { items(:forest_pdf) }
      old_vers_id = item.v_id
      assert item.update_redaction(:title=>'my forest')
      dv = item.send(:version)
      # new redaction points to old file
      assert_not_equal item.v_id  , old_vers_id
      assert_not_equal dv.file_ref, item.v_id
      assert_equal     dv.file_ref, old_vers_id
      
      visitor(:ant)
      set_lang('en')
      item = secure(Item) { items(:forest_pdf) }
      assert !item.update_redaction(:file=>uploaded_pdf('water.pdf')), "Cannot be changed"
      assert_match %r{file cannot be changed}, item.errors[:version]
    end
  end
  
  def test_can_make_a_new_redaction
    preserving_files("/data/test/pdf") do
      visitor(:ant)
      set_lang('fr')
      item = secure(Item) { items(:forest_pdf) }
      old_vers_id = item.v_id
      assert item.update_redaction(:title=>'my forest')
      dv = item.send(:version)
      # new redaction points to old file
      assert_not_equal item.v_id  , old_vers_id
      assert_not_equal dv.file_ref, item.v_id
      assert_equal     dv.file_ref, old_vers_id
      
      item.update_redaction(:file=>uploaded_pdf('water.pdf'))
      # new redaction points to new file
      assert_equal     dv.file_ref, item.v_id
      assert_not_equal dv.file_ref, old_vers_id
      assert item.save, "Save succeeds"
    end
  end
  
  def test_create_doc_file
    without_files("/data/test/pdf") do
      visitor(:ant)
      item = secure(Document) { Document.new( :parent_id=>items_id(:cleanWater),
                                                :name=>'report', 
                                                :file => uploaded_pdf('water.pdf') ) }
      dv  = item.send(:version)
      assert_nil dv[:file_ref]
      assert item.save, "Can save item"
      assert !dv.new_record?, "Not a new record"
      assert_equal dv[:file_ref], dv[:id]
      assert_kind_of DocFile, dv.file
      assert !dv.file.new_record?, "Not a new record"
      assert File.exist?("#{RAILS_ROOT}/data/test/pdf/#{item.v_id}/report.pdf")
    end
  end
end
