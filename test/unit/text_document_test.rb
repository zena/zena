require 'test_helper'

class TextDocumentTest < Zena::Unit::TestCase

  def test_create_simplest
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'skiny')}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 0, doc.version.content.size
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :name=>'medium', :v_text=>"12345678901234567890")}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 20, doc.version.content.size
  end

  def test_create_with_file
    login(:tiger)
    next_id = Version.find(:first, :order=>"id DESC")[:id] + 1
    file = uploaded_text('some.txt', 'stupid.jpg')
    doc = secure!(Document) { Document.create( :parent_id => nodes_id(:cleanWater),
                                               :c_file => file ) }
    assert_equal TextDocument, doc.class
    # reload
    doc = secure!(Document) { Document.find(doc[:id])}
    assert !File.exist?(doc.version.content.filepath), "No file created"
    assert_equal 'txt', doc.version.content.ext
    assert_equal 'text/plain', doc.version.content.content_type
    assert_equal 'stupid.txt', doc.version.content.filename
    assert_equal 40, doc.version.content.size
  end

  def test_content_lang
    login(:tiger)
    doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :v_title => 'super script',
                                              :c_content_type => 'text/x-ruby-script')}

    assert !doc.new_record?, "Not a new record"
    assert_equal TextDocument, doc.class
    assert_equal 'ruby', doc.content_lang

    doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:wiki_skin), :v_title => 'super script',
                                              :c_content_type => 'text/html')}
    assert_equal Template, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 'zafu', doc.content_lang
  end

  def test_parse_assets
    login(:lion)
    node = secure!(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert bird.update_attributes(:parent_id => node[:parent_id])
    start =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('bird.jpg') }
    #footer { background:url('/projects/wiki/flower.jpg') }
    END_CSS
    node.version.text = start.dup
    # dummy controller
    helper = ApplicationController.new
    helper.instance_variable_set(:@visitor, visitor)
    text = node.parse_assets(start, helper, 'v_text')
    assert node.errors.empty?
    res =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('/en/image30.jpg') }
    #footer { background:url('/en/image31.jpg') }
    END_CSS
    assert_equal res, text
    text = node.parse_assets(text, helper, 'v_text')
    assert_equal res, text
    text = node.unparse_assets(text, helper, 'v_text')
    assert_equal start, text
    text = node.unparse_assets(text, helper, 'v_text')
    assert_equal start, text
  end

  def test_parse_assets_with_underscore
    login(:lion)
    node = secure!(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert bird.update_attributes(:parent_id => node[:parent_id], :name => "greenBird")
    start =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('green_bird.jpg') }
    #tiny   { background:url('green_bird_tiny.jpg') }
    #footer { background:url('/projects/wiki/flower.jpg') }
    END_CSS
    node.version.text = start.dup
    # dummy controller
    helper = ApplicationController.new
    helper.instance_variable_set(:@visitor, visitor)
    text = node.parse_assets(start, helper, 'v_text')
    assert node.errors.empty?
    res =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('/en/image30.jpg') }
    #tiny   { background:url('/en/image30_tiny.jpg') }
    #footer { background:url('/en/image31.jpg') }
    END_CSS
    assert_equal res, text
  end

  def test_update_same_text
    login(:tiger)
    textdoc = secure(TextDocument) { TextDocument.create(:parent_id=>nodes_id(:cleanWater), :c_file => uploaded_text('some.txt'), :v_status => Zena::Status[:pub])}
    assert_equal uploaded_text('some.txt').size, textdoc.version.content.size
    textdoc.send(:update_attribute_without_fuss, :updated_at, Time.gm(2006,04,11))
    assert_equal Zena::Status[:pub], textdoc.version.status
    textdoc = secure(Node) { Node.find(textdoc[:id]) }
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(uploaded_text('some.txt').read)
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(textdoc.version.content.file.read)
    textdoc.version.content.file.rewind
    assert_equal 1, textdoc.versions.count
    assert_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
    assert textdoc.update_attributes(:c_file => uploaded_text('some.txt'))
    assert_equal 1, textdoc.versions.count
    assert_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
    assert textdoc.update_attributes(:c_file => uploaded_text('other.txt'))
    assert_equal 2, textdoc.versions.count
    assert_not_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
  end
end
