require 'test_helper'
require 'fileutils'

class DocumentTest < Zena::Unit::TestCase

  self.use_transactional_fixtures = false

  context 'On create a document' do
    setup { login(:ant) }
    subject do
        @doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                  :file => uploaded_pdf('water.pdf') ) }
    end

    should 'save object in database' do
      assert !subject.new_record?
    end

    should 'save file in file system' do
      assert File.exist?(subject.version.filepath)
    end

    should 'save content type in properties' do
      assert_equal 'application/pdf', subject.prop['content_type']
    end

    should 'save extension in properties' do
      assert_equal 'pdf', subject.prop['ext']
    end

    should 'save title in version' do
      assert_not_nil subject.version.title
    end

    should 'save name in document' do
      assert_not_nil subject.name
    end

    should 'save visitor id in attachment' do
      assert_equal users_id(:ant), subject.version.attachment.user_id
    end

    should 'save site id in attachment' do
      assert_equal sites_id(:zena), subject.version.attachment.site_id
    end
  end

  context 'On create with same name' do
    setup do
      login(:tiger)
      @doc = secure!(Document) { Document.create( :parent_id => nodes_id(:cleanWater),
                                                 :title => 'lake',
                                                 :file  => uploaded_pdf('water.pdf') ) }
    end

    should 'save name with increment' do
      assert_equal 'lake-1', @doc.name
    end

    should 'save version title with increment' do
      assert_equal 'lake-1', @doc.version.title
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
      assert_equal "My new project", doc.version.title
      v = doc.send :version
    end
  end

  def test_create_without_file
    login(:ant)
    doc = secure!(Document) { Document.new(:parent_id=>nodes_id(:cleanWater), :name=>'lalala') }
    assert_kind_of TextDocument, doc
    assert_equal 'text/plain', doc.version.content.content_type
    assert doc.save, "Can save"
  end

  def test_create_with_content_type
    login(:tiger)
    doc = secure!(Template) { Template.create("name"=>"Node_tree", "c_content_type"=>"text/css", "c_mode"=>"tree", "c_klass"=>"Node", "v_summary"=>"", "parent_id"=>nodes_id(:default))}
    assert !doc.kind_of?(Template)
    assert_kind_of TextDocument, doc
    assert !doc.new_record?, "Not a new record"
    assert_equal 'text/css', doc.version.content.content_type
    assert_equal 'css', doc.version.content.ext
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
      assert_equal "stupid", doc.version.title
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
    assert_nothing_raised { doc.version.content.size }
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
      assert_equal "stupid", doc.version.title
      assert_equal 'txt', doc.version.content.ext
    end
  end

  def test_change_file
    preserving_files('/test.host/data') do
      login(:tiger)
      doc = secure!(Document) { Document.find(nodes_id(:water_pdf)) }
      assert_equal 29279, doc.version.content.size
      assert_equal file_path(:water_pdf), doc.version.content.filepath
      content_id = doc.version.content.id
      # new redaction in 'en'
      assert doc.update_attributes(:c_file=>uploaded_pdf('forest.pdf'), :v_title=>'forest gump'), "Can change file"
      assert_not_equal content_id, doc.version.content.id
      assert !doc.version.content.new_record?
      doc = secure!(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.version.title
      assert_equal 'pdf', doc.version.content.ext
      assert_equal 63569, doc.version.content.size
      last_id = Version.find(:first, :order=>"id DESC").id
      assert_not_equal versions_id(:water_pdf_en), last_id
      # filepath is set from initial node name
      assert_equal file_path('water.pdf', 'full', doc.version.content.id), doc.version.content.filepath
      assert doc.update_attributes(:c_file=>uploaded_pdf('water.pdf')), "Can change file"
      doc = secure!(Node) { nodes(:water_pdf) }
      assert_equal 'forest gump', doc.version.title
      assert_equal 'pdf', doc.version.content.ext
      assert_equal 29279, doc.version.content.size
      assert_equal file_path('water.pdf', 'full', doc.version.content.id), doc.version.content.filepath
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
      assert_equal "report...", doc.version.title
      assert_equal 'report', doc.version.content.name
      assert_equal "report....pdf", doc.filename
      assert_equal 'pdf', doc.version.content.ext
    end
  end

  def test_create_with_file_name_unknown_ext
    without_files('/test.host/data') do
      login(:ant)
      doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                                :c_file  => uploaded_fixture("some.txt", 'application/octet-stream', "super.zz") ) }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "super", doc.name
      assert_equal "super", doc.version.title
      assert_equal 'super', doc.version.content.name
      assert_equal "super.zz", doc.filename
      assert_equal 'zz', doc.version.content.ext
      assert_equal 'application/octet-stream', doc.version.content.content_type
    end
  end

  def test_destroy_many_versions
    preserving_files('/test.host/data') do
      login(:tiger)
      doc = secure!(Node) { nodes(:water_pdf) }
      filepath = doc.version.content.filepath
      assert File.exist?(filepath), "File path #{filepath.inspect} exists"
      first = doc.version.number
      content_id = doc.version.content.id
      assert doc.update_attributes(:v_title => 'WahWah')
      second = doc.version.number
      assert first != second
      assert_equal content_id, doc.version.content.id # shared content
      doc = secure!(Node) { nodes(:water_pdf) }
      doc.version(first)
      assert doc.unpublish
      assert doc.can_destroy_version?
      assert doc.destroy_version
      doc = secure!(Node) { nodes(:water_pdf) }
      assert File.exist?(filepath)
      assert_equal content_id, doc.version.content.id # shared content note destroyed
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
                                                :c_file  => uploaded_fixture('water.pdf', 'application/pdf', 'wat'), :v_title => "lazy waters.pdf") }
      assert_kind_of Document , doc
      assert ! doc.new_record? , "Not a new record"
      assert_equal "lazyWaters", doc.name
      assert_equal "lazy waters", doc.version.title
      assert_equal 'lazyWaters', doc.version.content.name
      assert_equal "lazyWaters.pdf", doc.filename
      assert_equal 'pdf', doc.version.content.ext
      assert_equal 'application/pdf', doc.version.content.content_type
    end
  end

end
