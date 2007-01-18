require File.dirname(__FILE__) + '/../test_helper'

class DocumentContentTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_img_tag
    visitor(:tiger)
    doc = document_contents(:water_pdf)
    assert_equal "<img src='/images/ext/pdf.png' width='32' height='32' class='icon'/>", doc.img_tag
    assert_equal "<img src='/images/ext/pdf-pv.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/pdf-std.png' width='32' height='32' class='std'/>", doc.img_tag('std')
  end
  
  def test_img_tag_other
    visitor(:tiger)
    doc = document_contents(:water_pdf)
    doc.ext = 'bin'
    assert_equal 'bin', doc.ext
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' class='icon'/>", doc.img_tag
    assert_equal "<img src='/images/ext/other-pv.png' width='80' height='80' class='pv'/>", doc.img_tag('pv')
    assert_equal "<img src='/images/ext/other-std.png' width='32' height='32' class='std'/>", doc.img_tag('std')
  end
  
  def test_set_file
    doc = DocumentContent.new
    assert_nothing_raised { doc.file = uploaded_pdf('water.pdf') }
    assert_equal 'application/pdf', doc.content_type
    assert_equal 29279, doc.size
  end
  
  def test_file
    doc = DocumentContent.new( :file=>uploaded_pdf('water.pdf') )
    data = nil
    assert_nothing_raised { data = doc.file }
    assert_equal data.read, uploaded_pdf('water.pdf').read
    doc = DocumentContent.new( :version_id=>7)
    assert_raise(IOError) { doc.file }
  end
  
  def test_set_size
    imf = DocumentContent.new
    assert_raise(StandardError) { imf.size = 34 }
  end
  
  def test_filename
    doc = DocumentContent.new( :name=>'bob', :version_id=>versions_id(:water_pdf_en), :ext=>'tot' )
    assert_equal 'bob.tot', doc.filename
  end
  
  def test_change_name
    without_files("/data/test/pdf/15") do
      doc = DocumentContent.new( :version_id=>15, :file=>uploaded_pdf('water.pdf') )
      assert !File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert doc.save, "Can save"
      assert File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      doc.name = 'blom'
      assert doc.save, "Can save"
      # name must be the same as 'node'
      assert_equal "#{RAILS_ROOT}/data/test/pdf/15/water.pdf", doc.filepath
      doc.version.node.name = 'blom'
      assert doc.save, "Can save"
      assert_equal "#{RAILS_ROOT}/data/test/pdf/15/blom.pdf", doc.filepath
      assert !File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert File.exist?("#{RAILS_ROOT}/data/test/pdf/15/blom.pdf")
    end
  end
  
  def test_filepath
    without_files('/data/test/pdf/14') do
      doc = DocumentContent.create( :version_id=>versions_id(:water_pdf_en), :ext=>'tic', :name=>'abc', :file => uploaded_pdf('forest.pdf') )
      assert_equal "#{RAILS_ROOT}/data/test/pdf/15/water.pdf", doc.filepath
    end
  end
      
  def test_filepath_without_version
    doc = DocumentContent.new( :file=>uploaded_pdf('water.pdf') )
    assert_raise(StandardError) { doc.filepath }
  end
  
  def test_filepath_ok
    without_files('/data/test/jpg') do
      doc = DocumentContent.create( :version_id=>versions_id(:bird_jpg_en), :ext=>'jpg' )
      assert_equal "#{RAILS_ROOT}/data/test/jpg/#{versions_id(:bird_jpg_en)}/bird.jpg", doc.filepath
    end
  end
  
  def test_save_file
    without_files("/data/test/pdf/15") do
      doc = DocumentContent.new( :version_id=>15, :file=>uploaded_pdf('water.pdf') )
      assert !File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert doc.save, "Can save"
      assert File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert_equal 29279, doc.size
      doc = DocumentContent.find(doc.id)
      assert doc.save, "Can save again"
      doc.file = uploaded_pdf('forest.pdf')
      assert doc.save, "Can save"
      assert_equal 63569, doc.size
    end
  end
  
  def test_destroy
    preserving_files('data/test/pdf/15') do
      doc = DocumentContent.find(document_contents_id(:water_pdf))
      assert_equal DocumentContent, doc.class
      assert File.exist?(doc.filepath), "File exist"
      assert doc.destroy, "Can destroy"
      assert !File.exist?(doc.filepath), "File does not exist"
      assert !File.exist?("#{RAILS_ROOT}/data/test/pdf/15"), "Directory does not exist"
    end
  end
  
  def test_has_file
    visitor(:ant)
    doc = secure(Document) { Document.new(:parent_id=>nodes_id(:cleanWater), :name=>'lalala', :c_name=>'wak') }
    assert ! doc.save, 'Cannot save'
    assert_equal "can't be blank", doc.errors[:c_file]
  end
  
  def test_wrong_file_type
    preserving_files("/data/test/jpg/20") do
      visitor(:tiger)
      node = secure(Node) { nodes(:bird_jpg) }
      assert !node.update_attributes(:c_file=>uploaded_pdf('water.pdf'))
      assert_equal 'must be an image', node.errors[:c_file]
    end
  end
  
end
