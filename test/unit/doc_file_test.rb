require File.dirname(__FILE__) + '/../test_helper'

class DocFileTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_set_file
    doc = DocFile.new
    assert_nothing_raised { doc.file = uploaded_pdf('water.pdf') }
    assert_equal 'application/pdf', doc.content_type
    assert_equal 29279, doc.size
  end
  
  def test_read
    doc = DocFile.new( :file=>uploaded_pdf('water.pdf') )
    data = nil
    assert_nothing_raised { data = doc.read }
    assert_equal data, uploaded_pdf('water.pdf').read
    doc = DocFile.new
    assert_raise(IOError) { doc.read }
  end
  
  def test_set_size
    imf = DocFile.new
    assert_raise(StandardError) { imf.size = 34 }
  end
  
  def test_size
    DocFile.connection.execute "UPDATE doc_files SET size=NULL WHERE id=#{doc_files_id(:water_pdf)}"
    without_files('/data/test/pdf') do
      dof = DocFile.find(doc_files_id(:water_pdf))
      assert_nil dof[:size]
      assert_nil dof.size
    end
    dof = DocFile.find(doc_files_id(:water_pdf))
    assert_nil dof[:size]
    assert_equal 29279, dof.size
    assert_equal 29279, dof[:size]
    dof = DocFile.new
    dof.file = uploaded_pdf('water.pdf')
    assert_equal 29279, dof.size
  end
  
  
  def test_docfile_valid_no_version
    doc = DocFile.new( :file=>uploaded_pdf('water.pdf') )
    assert !doc.save
    assert_equal 'version must exist', doc.errors[:version_id]
  end
  
  def test_docfile_valid_no_file
    doc = DocFile.new( :version_id=>11 )
    assert !doc.save
    assert_equal 'file not set', doc.errors[:base]
  end
  
  def test_filename
    doc = DocFile.new( :version_id=>15 )
    assert_equal 'water.pdf', doc.send(:filename)
  end
  
  def test_make_path
    doc = DocFile.new( :version_id=>15 )
    assert_equal '', doc[:path]
    doc.send(:make_path)
    assert_equal '/pdf/15/water.pdf', doc[:path]
  end
  
  def test_filepath_without_version
    doc = DocFile.new( :file=>uploaded_pdf('water.pdf') )
    assert_raise(StandardError) { doc.send(:filepath) }
  end
  
  def test_filepath_ok
    doc = DocFile.new( :version_id=>15, :file=>uploaded_pdf('water.pdf') )
    fp = doc.send(:filepath)
    assert_equal "#{RAILS_ROOT}/data/test/pdf/15/water.pdf", fp
  end
  
  def test_save_file
    without_files("/data/test/pdf/15/water.pdf") do
      doc = DocFile.new( :version_id=>15, :file=>uploaded_pdf('water.pdf') )
      assert !File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert doc.save, "Can save"
      assert File.exist?("#{RAILS_ROOT}/data/test/pdf/15/water.pdf")
      assert_equal 29279, doc.size
      doc = DocFile.find(doc.id)
      assert doc.save, "Can save again"
      doc.file = uploaded_pdf('forest.pdf')
      assert doc.save, "Can save"
      assert_equal 63569, doc.size
    end
  end
end
