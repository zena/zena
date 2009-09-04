require 'test_helper'

class DocumentContentTest < Zena::Unit::TestCase
  
  def test_site_id
    without_files('/test.host/data/full') do
      doc = DocumentContent.create( :version_id=>versions_id(:water_pdf_en), :ext=>'tic', :name=>'abc', :file => uploaded_pdf('forest.pdf') )
      assert_equal sites_id(:zena), doc.site_id
    end
  end
  
  def test_site_id
    without_files('/test.host/data/full') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report', 
                                                :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      content = doc.v_content
      assert_kind_of DocumentContent, content
      assert_equal sites_id(:zena), content.site_id
      assert File.exist?(content.filepath)
      assert_equal File.stat(content.filepath).size, content.size
    end
  end
  
  def test_cannot_set_site_id
    without_files('/test.host/data/full') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report', 
                                                :c_file => uploaded_pdf('water.pdf') ) }
      

      assert !doc.new_record?, "Not a new record"
      assert_kind_of Document , doc
      content = doc.v_content
      assert_kind_of DocumentContent, content
      assert_equal sites_id(:zena), content.site_id
      assert_raise(Zena::AccessViolation) { doc.c_site_id   = sites_id(:ocean) }
      assert_raise(Zena::AccessViolation) { content.site_id = sites_id(:ocean) }
    end
  end
  
  def test_file
    doc = DocumentContent.new( :file=>uploaded_pdf('water.pdf') )
    data = nil
    assert_nothing_raised { data = doc.file }
    assert_equal data.read, uploaded_pdf('water.pdf').read
    doc = DocumentContent.new( :version_id=>7, :name => 'hoho', :ext => 'txt' )
    doc[:site_id] = sites_id(:zena)
    assert_raise(StandardError) { doc.file } # filepath not set
  end
  
  def test_set_size
    imf = DocumentContent.new
    assert_raise(StandardError) { imf.size = 34 }
  end
  
  def test_filepath_without_version
    doc = DocumentContent.new( :file=>uploaded_pdf('water.pdf') )
    assert_raise(StandardError) { doc.filepath }
  end
  
  def test_version
    version_id = versions_id(:water_pdf_en)
    doc = DocumentContent.new( :name=>'water', :version_id=> version_id )
    assert_equal version_id, doc.version_id
  end
  
  def test_save_file
    without_files("/test.host/data/full") do
      doc = DocumentContent.new( :name=>'water', :version_id=>versions_id(:water_pdf_en), :file=>uploaded_pdf('water.pdf') )
      doc[:site_id] = sites_id(:zena)
      assert doc.save, "Can save"
      assert File.exist?(file_path('water.pdf','full',doc[:id]))
      assert_equal 29279, doc.size
      doc = DocumentContent.find(doc.id)
      assert doc.save, "Can save again"
      doc.file = uploaded_pdf('forest.pdf')
      assert doc.save, "Can save"
      assert_equal 63569, doc.size
    end
  end
  
  def test_destroy
    preserving_files('/test.host/data/full') do
      doc = DocumentContent.find(document_contents_id(:water_pdf))
      assert_equal DocumentContent, doc.class
      assert File.exist?(doc.filepath), "File exist"
      assert doc.destroy, "Can destroy"
      assert !File.exist?(doc.filepath), "File does not exist"
      directory = File.dirname(file_path(:water_pdf))
      parent_di = File.dirname(directory)
      assert !File.exist?(directory), "Directory does not exist"
      assert !File.exist?(parent_di), "Parent directory does not exist"
    end
  end
  
  def test_wrong_file_type
    preserving_files("/test.host/data/jpg/20") do
      login(:tiger)
      node = secure!(Node) { nodes(:bird_jpg) }
      assert !node.update_attributes(:c_file=>uploaded_pdf('water.pdf'))
      assert_equal 'must be an image', node.errors[:version_content_file]
    end
  end
  
  def test_would_edit
    doc = document_contents(:bird_jpg)
    assert doc.would_edit?('file' => uploaded_pdf('water.pdf'))
    assert !doc.would_edit?('file' => uploaded_pdf('bird.jpg'))
  end
  
end
