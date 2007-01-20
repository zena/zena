require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'
class DocumentTest < Test::Unit::TestCase
  include ZenaTestUnit
  
  def test_callbacks_for_documents
    assert Node.read_inheritable_attribute(:before_validation).include?(:secure_before_validation)
    assert Document.read_inheritable_attribute(:validate_on_create).include?(:node_on_create)
    assert Document.read_inheritable_attribute(:validate_on_update).include?(:node_on_update)
    assert Document.read_inheritable_attribute(:before_validation).include?(:set_name)
    assert Document.read_inheritable_attribute(:before_save).include?(:update_content_name)
  end
  
  def test_create_with_file
    without_files('/data/test/pdf') do
      test_visitor(:ant)
      doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :name=>'report', 
                                                :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "report", doc.name
      assert_equal "report", doc.v_title
      assert_equal "report.pdf", doc.c_filename
      assert_equal 'pdf', doc.c_ext
      assert ! doc.v_new_record? , "Version is not a new record"
      assert_not_nil doc.c_id , "Content id is set"
      assert_kind_of DocumentContent , doc.v_content
      assert_equal "#{RAILS_ROOT}/data/test/pdf/#{doc.v_id}/report.pdf", doc.c_filepath
      assert File.exist?(doc.c_filepath)
      assert_equal File.stat(doc.c_filepath).size, doc.c_size
    end
  end
  
  def test_create_with_bad_filename
    preserving_files('/data/test/pdf') do
      test_visitor(:ant)
      doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :v_title => 'My new project',
                                                :c_file => uploaded_pdf('water.pdf', 'stupid.jpg') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "stupid.pdf", doc.name
      assert_equal "My new project", doc.v_title
      v = doc.send :version
    end
  end
  
  def test_create_with_duplicate_name
    preserving_files('/data/test/pdf') do
      test_visitor(:ant)
      doc = secure(Document) { Document.create( :parent_id=>nodes_id(:wiki),
        :v_title => 'bird.jpg',
        :c_file => uploaded_pdf('bird.jpg') ) }
        assert_kind_of Document , doc
        assert_equal 'bird', doc.name
        assert doc.new_record? , "Not saved"
        assert_equal "bird", doc.name
        assert_equal "has already been taken", doc.errors[:name]
      end
  end
  
  def test_create_with_bad_filename
    preserving_files('/data/test/pdf') do
      test_visitor(:ant)
      doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
        :name => 'stupid.jpg',
        :c_file => uploaded_pdf('water.pdf') ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "stupid", doc.name
      assert_equal "stupid", doc.v_title
      assert_equal "stupid.pdf", doc.c_filename
    end
  end
  
  def get_with_full_path
    test_visitor(:tiger)
    doc = secure(Document) { Document.find_by_path( visitor_id, visitor_groups, lang, "/projects/cleanWater/water.pdf") }
    assert_kind_of Document, doc
    assert_equal "/projects/cleanWater/water.pdf", doc.fullpath
  end
  
  def test_image
    test_visitor(:tiger)
    doc = secure(Document) { Document.find( nodes_id(:water_pdf) ) }
    assert ! doc.image?, 'Not an image'
    doc = secure(Document) { Document.find( nodes_id(:bird_jpg) )  }
    assert doc.image?, 'Is an image'
  end
  
  def test_filename
    test_visitor(:tiger)
    doc = secure(Node) { nodes(:lake_jpg) }
    assert_equal 'lake.jpg', doc.filename
    doc.name = 'test'
    assert_equal 'test.jpg', doc.filename
    doc.c_ext = 'pdf'
    assert_equal 'test.pdf', doc.filename
  end
  
  def test_c_img_tag
    test_visitor(:tiger)
    doc = secure(Document) { Document.find( nodes_id(:water_pdf) ) }
    assert_nothing_raised { doc.img_tag; doc.img_tag('std') }
  end
  
  def test_filesize
    test_visitor(:tiger)
    doc = secure(Document) { Document.find( nodes_id(:water_pdf) ) }
    assert_nothing_raised { doc.c_size }
  end
  
  def test_create_with_text_file
    preserving_files('/data/test/txt') do
      test_visitor(:ant)
      doc = secure(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
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
    preserving_files('/data/test/pdf') do
      test_visitor(:tiger)
      doc = secure(Document) { Document.find(nodes_id(:water_pdf)) }
      assert_equal 29279, doc.c_size
      assert_equal "#{RAILS_ROOT}/data/test/pdf/15/water.pdf", doc.c_filepath
      # new redaction in 'en'
      assert doc.update_attributes(:c_file=>uploaded_pdf('forest.pdf'), :v_title=>'forest gump'), "Can change file"
      
      doc = secure(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.v_title
      assert_equal 'pdf', doc.c_ext
      assert_equal 63569, doc.c_size
      last_id = Version.find(:first, :order=>"id DESC").id
      assert_not_equal 15, last_id
      assert_equal "#{RAILS_ROOT}/data/test/pdf/#{last_id}/water.pdf", doc.c_filepath
      assert doc.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Can change file"
      doc = secure(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.v_title
      assert_equal 'pdf', doc.c_ext
      assert_equal 29279, doc.c_size
      assert_equal "#{RAILS_ROOT}/data/test/pdf/#{last_id}/water.pdf", doc.c_filepath
    end
  end
      
end
