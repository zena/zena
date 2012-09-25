require 'test_helper'

class TextDocumentTest < Zena::Unit::TestCase

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a css text_document' do
      subject do
        secure(Node) { nodes(:style_css) }
      end

      context 'in a folder with an image' do
        setup do
          bird = secure!(Node) { nodes(:bird_jpg) }
          previous_updated_at = bird.updated_at
          assert bird.update_attributes(:parent_id => subject[:parent_id])
          # We want to keep the updated_at date
          Zena::Db.set_attribute(bird, :updated_at, previous_updated_at)
        end

        should 'parse css assets' do
          css =<<-END_CSS
          body { font-size:10px; }
          #header { background:url('bird.jpg') }
          #pv     { background:url('bird_pv.jpg') }
          #footer { background:url('/projects list/a wiki with Zena/flower.jpg') }
          #no_stamp { background:url('/en/image30_pv.7f6f0.jpg') }
          END_CSS

          assert subject.update_attributes(:text => css)

          parsed_css =<<-END_CSS
          body { font-size:10px; }
          #header { background:url('/en/image30.11fbc.jpg') }
          #pv     { background:url('/en/image30_pv.7f6f0.jpg') }
          #footer { background:url('/en/image31.11fbc.jpg') }
          #no_stamp { background:url('/en/image30_pv.7f6f0.jpg') }
          END_CSS

          assert_equal parsed_css, subject.text

          # Reload
          node = secure(Node) { nodes(:style_css) }
          assert_equal parsed_css, node.text
        end
      end # in a folder with an image
    end # on a css text_document

    context 'creating a text document' do
      context 'with a content_type' do
        subject do
          secure!(TextDocument) { TextDocument.create(
            :title => "yoba",
            :parent_id => nodes_id(:wiki),
            :text => "#header { color:red; }\n#footer { color:blue; }",
            :content_type => 'text/css')
          }
        end

        should 'create a new TextDocument' do
          assert_difference('TextDocument.count', 1) do
            subject
          end
        end

        should 'set extension from content_type' do
          assert_equal 'css', subject.ext
        end
      end # with a content_type
    end # creating a text document
  end # A visitor with write access

  def test_create_simplest
    login(:tiger)
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :title => 'skiny')}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 0, doc.size
    doc = secure!(Document) { Document.create(:parent_id=>nodes_id(:cleanWater), :title => 'medium', :text=>"12345678901234567890")}
    assert_equal TextDocument, doc.class
    assert !doc.new_record?, "Not a new record"
    assert_equal 20, doc.size
  end

  def test_create_with_file
    login(:tiger)
    next_id = Version.find(:first, :order=>"id DESC")[:id] + 1
    file = uploaded_text('some.txt')
    doc = secure!(Document) { Document.create( :parent_id => nodes_id(:cleanWater),
                                               :file => file ) }

    assert_equal TextDocument, doc.class
    # reload
    doc = secure!(Document) { Document.find(doc[:id])}
    assert_nil doc.filepath
    assert_equal 'txt', doc.ext
    assert_equal 'text/plain', doc.content_type
    assert_equal 'some.txt', doc.filename
    assert_equal 40, doc.size
  end

  def test_content_lang
    login(:tiger)
    doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title => 'super script',
                                              :content_type => 'text/x-ruby-script')}

    assert !doc.new_record?, "Not a new record"
    assert_equal TextDocument, doc.class
    assert_equal 'ruby', doc.content_lang
    # doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater), :title => 'super script',
    #                                           :content_type => 'text/html')}
    # assert_equal Template, doc.class
    # assert !doc.new_record?, "Not a new record"
    # assert_equal 'zafu', doc.content_lang
  end

  def test_parse_assets
    login(:lion)
    node = secure!(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    b_at = bird.updated_at
    assert bird.update_attributes(:parent_id => node[:parent_id])
    Zena::Db.set_attribute(bird, :updated_at, b_at)
    start =<<-END_CSS
    body { font-size:10px; behavior:url("/stylesheets/csshover2.htc"); }
    #header { background:url('bird.jpg') }
    #pv     { background:url('bird_pv.jpg') }
    #footer { background:url('/projects list/a wiki with Zena/flower.jpg') }
    #back   { background:url('../../../projects list/a wiki with Zena/flower.jpg') }
    #no_stamp { background:url('/en/image30_pv.jpg') }
    END_CSS
    node.text = start.dup
    # dummy controller
    helper = ApplicationController.new
    helper.instance_variable_set(:@visitor, visitor)
    text = node.parse_assets(start, helper, 'text')
    err node
    assert node.errors.empty?
    res =<<-END_CSS
    body { font-size:10px; behavior:url("/stylesheets/csshover2.htc?#{File.mtime(File.join(RAILS_ROOT, 'public/stylesheets/csshover2.htc')).to_i}"); }
    #header { background:url('/en/image30.11fbc.jpg') }
    #pv     { background:url('/en/image30_pv.7f6f0.jpg') }
    #footer { background:url('/en/image31.11fbc.jpg') }
    #back   { background:url('/en/image31.11fbc.jpg') }
    #no_stamp { background:url('/en/image30_pv.7f6f0.jpg') }
    END_CSS
    assert_equal res, text
    text = node.parse_assets(text, helper, 'text')
    assert_equal res, text
    text = node.unparse_assets(text, helper, 'text')
    unparsed =<<-END_CSS
    body { font-size:10px; behavior:url("/stylesheets/csshover2.htc"); }
    #header { background:url('bird.jpg') }
    #pv     { background:url('bird_pv.jpg') }
    #footer { background:url('/projects list/a wiki with Zena/flower.jpg') }
    #back   { background:url('/projects list/a wiki with Zena/flower.jpg') }
    #no_stamp { background:url('bird_pv.jpg') }
    END_CSS
    assert_equal unparsed, text
    text = node.unparse_assets(text, helper, 'text')
    assert_equal unparsed, text
  end

  def test_parse_assets_with_underscore
    login(:lion)
    node = secure!(Node) { nodes(:style_css) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    b_at = bird.updated_at
    # We need to publish so that the title is used for fullpath
    assert bird.update_attributes(:parent_id => node[:parent_id], :title => "green_bird", :v_status => Zena::Status::Pub)
    Zena::Db.set_attribute(bird, :updated_at, b_at)
    start =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('green_bird.jpg') }
    #tiny   { background:url('green_bird_tiny.jpg') }
    #footer { background:url('/projects list/a wiki with Zena/flower.jpg') }
    END_CSS
    node.text = start.dup
    # dummy controller
    helper = ApplicationController.new
    helper.instance_variable_set(:@visitor, visitor)
    text = node.parse_assets(start, helper, 'text')
    assert node.errors.empty?
    res =<<-END_CSS
    body { font-size:10px; }
    #header { background:url('/en/image30.11fbc.jpg') }
    #tiny   { background:url('/en/image30_tiny.0059b.jpg') }
    #footer { background:url('/en/image31.11fbc.jpg') }
    END_CSS
    assert_equal res, text
  end

  def test_update_same_text
    login(:tiger)
    textdoc = secure(TextDocument) { TextDocument.create(:parent_id=>nodes_id(:cleanWater), :file => uploaded_text('some.txt'), :v_status => Zena::Status::Pub)}
    assert_equal uploaded_text('some.txt').size, textdoc.size
    Zena::Db.set_attribute(textdoc, :updated_at, Time.gm(2006,04,11))
    assert_equal Zena::Status::Pub, textdoc.version.status
    textdoc = secure(Node) { Node.find(textdoc[:id]) }
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(uploaded_text('some.txt').read)
    assert_equal '21a6948e0aec6de825009d8fda44f7e4', Digest::MD5.hexdigest(textdoc.file.read)
    textdoc.file.rewind
    assert_equal 1, textdoc.versions.count
    assert_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
    assert textdoc.update_attributes(:file => uploaded_text('some.txt'))
    assert_equal 1, textdoc.versions.count
    assert_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
    textdoc.version.backup = true
    assert textdoc.update_attributes(:file => uploaded_text('other.txt'))
    assert_equal 2, textdoc.versions.count
    assert_not_equal '2006-04-11 00:00', textdoc.updated_at.strftime('%Y-%m-%d %H:%M')
  end
end
