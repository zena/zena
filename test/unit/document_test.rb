require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'
class DocumentTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end
  
  def test_create_with_file
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report', 
                                                :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "report", doc.name
      assert_equal "report", doc.v_title
      assert_equal "report.pdf", doc.filename
      assert_equal 'pdf', doc.c_ext
      assert ! doc.v_new_record? , "Version is not a new record"
      assert_not_nil doc.c_id , "Content id is set"
      assert_kind_of DocumentContent , doc.v_content
      assert File.exist?(doc.c_filepath)
      assert_equal File.stat(doc.c_filepath).size, doc.c_size
    end
  end
  
  def test_create_with_bad_filename
    preserving_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :v_title => 'My new project',
                                                :c_file => uploaded_pdf('water.pdf', 'stupid.jpg') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "stupid.pdf", doc.name
      assert_equal "My new project", doc.v_title
      v = doc.send :version
    end
  end

  def test_create_without_file
    login(:ant)
    doc = secure!(Document) { Document.new(:parent_id=>nodes_id(:cleanWater), :name=>'lalala') }
    assert_kind_of TextDocument, doc
    assert_equal 'text/plain', doc.c_content_type
    assert doc.save, "Can save"
  end
  
  def test_create_with_content_type
    login(:tiger)
    doc = secure!(Template) { Template.create("name"=>"Node_tree", "c_content_type"=>"text/css", "c_mode"=>"tree", "c_klass"=>"Node", "v_summary"=>"", "parent_id"=>nodes_id(:default))}
    assert !doc.kind_of?(Template)
    assert_kind_of TextDocument, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/css', doc.c_content_type
    assert_equal 'css', doc.c_ext
  end
  
  def test_create_with_duplicate_name
    preserving_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:wiki),
        :v_title => 'bird.jpg',
        :c_file => uploaded_pdf('bird.jpg') ) }
        assert_kind_of Document , doc
        assert_equal 'bird-1', doc.name
        assert !doc.new_record? , "Saved"
        assert_equal "bird-1", doc.name
      end
  end
  
  def test_create_with_bad_filename
    preserving_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
        :name => 'stupid.jpg',
        :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "stupid", doc.name
      assert_equal "stupid", doc.v_title
      assert_equal "stupid.pdf", doc.filename
    end
  end
  
  def get_with_full_path
    login(:tiger)
    doc = secure!(Document) { Document.find_by_path("/projects/cleanWater/water.pdf") }
    assert_kind_of Document, doc
    assert_equal "/projects/cleanWater/water.pdf", doc.fullpath
  end
  
  def test_image
    login(:tiger)
    doc = secure!(Document) { Document.find( nodes_id(:water_pdf) ) }
    assert ! doc.image?, 'Not an image'
    doc = secure!(Document) { Document.find( nodes_id(:bird_jpg) )  }
    assert doc.image?, 'Is an image'
  end
  
  def test_filename
    login(:tiger)
    doc = secure!(Node) { nodes(:lake_jpg) }
    assert_equal 'lake.jpg', doc.filename
    doc.name = 'test'
    assert_equal 'test.jpg', doc.filename
    doc.update_attributes('c_ext' => 'pdf')
    assert_equal 'test.jpg', doc.filename
  end
  
  def test_filesize
    login(:tiger)
    doc = secure!(Document) { Document.find( nodes_id(:water_pdf) ) }
    assert_nothing_raised { doc.c_size }
  end
  
  def test_create_with_text_file
    preserving_files('/test.host/data/txt') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
        :name => 'stupid.jpg',
        :c_file => uploaded_text('some.txt') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "stupid", doc.name
      assert_equal "stupid", doc.v_title
      assert_equal 'txt', doc.c_ext
    end
  end
  
  def test_change_file
    preserving_files('/test.host/data') do
      login(:tiger)
      doc = secure!(Document) { Document.find(nodes_id(:water_pdf)) }
      assert_equal 29279, doc.c_size
      assert_equal file_path(:water_pdf), doc.c_filepath
      content_id = doc.c_id
      # new redaction in 'en'
      assert doc.update_attributes(:c_file=>uploaded_pdf('forest.pdf'), :v_title=>'forest gump'), "Can change file"
      assert_not_equal content_id, doc.c_id
      assert !doc.c_new_record?
      doc = secure!(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.v_title
      assert_equal 'pdf', doc.c_ext
      assert_equal 63569, doc.c_size
      last_id = Version.find(:first, :order=>"id DESC").id
      assert_not_equal versions_id(:water_pdf_en), last_id
      # filepath is set from initial node name
      assert_equal file_path('water.pdf', 'full', doc.c_id), doc.c_filepath
      assert doc.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Can change file"
      doc = secure!(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.v_title
      assert_equal 'pdf', doc.c_ext
      assert_equal 29279, doc.c_size
      assert_equal file_path('water.pdf', 'full', doc.c_id), doc.c_filepath
    end
  end 
  
  
  def test_create_with_file_name_has_dots
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report...', 
                                                :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "report...", doc.name
      assert_equal "report...", doc.v_title
      assert_equal 'report', doc.c_name
      assert_equal "report....pdf", doc.filename
      assert_equal 'pdf', doc.c_ext
    end
  end
  
  def test_create_with_file_name_unknown_ext
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :c_file  => uploaded_file("some.txt", 'application/octet-stream', "super.zz") ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "super", doc.name
      assert_equal "super", doc.v_title
      assert_equal 'super', doc.c_name
      assert_equal "super.zz", doc.filename
      assert_equal 'zz', doc.c_ext
      assert_equal 'application/octet-stream', doc.c_content_type
    end
  end
  
  def test_destroy_many_versions
    preserving_files('/test.host/data') do
      login(:tiger)
      doc = secure!(Node) { nodes(:water_pdf) }
      filepath = doc.c_filepath
      assert File.exist?(filepath), "File path #{filepath.inspect} exists"
      first = doc.v_number
      content_id = doc.c_id
      assert doc.update_attributes(:v_title => 'WahWah')
      second = doc.v_number
      assert first != second
      assert_equal content_id, doc.c_id # shared content
      doc = secure!(Node) { nodes(:water_pdf) }
      doc.version(first)
      assert doc.unpublish
      assert doc.can_destroy_version?
      assert doc.destroy_version
      err doc
      doc = secure!(Node) { nodes(:water_pdf) }
      assert File.exist?(filepath)
      assert_equal content_id, doc.c_id # shared content note destroyed
      assert doc.remove
      assert doc.destroy_version
      assert_nil DocumentContent.find_by_id(content_id)
      assert ! File.exist?(filepath)
    end
  end
  
  def test_set_v_title
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :c_file  => uploaded_file('water.pdf', 'application/pdf', 'wat'), :v_title => "lazy waters.pdf") }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "lazyWaters", doc.name
      assert_equal "lazy waters", doc.v_title
      assert_equal 'lazyWaters', doc.c_name
      assert_equal "lazyWaters.pdf", doc.filename
      assert_equal 'pdf', doc.c_ext
      assert_equal 'application/pdf', doc.c_content_type
    end
  end
  
end
