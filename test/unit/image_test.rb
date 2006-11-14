require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :items, :versions, :doc_files

  def test_create_with_file
    visitor(:ant)
    doc = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater),
                                        :inherit => 1,
                                        :name=>'birdy', 
                                        :file => fixture_file_upload('/files/bird.jpg', 'image/jpeg')) }
    assert_kind_of Image , doc
    assert ! doc.new_record? , "Not a new record"
    assert_equal "birdy.jpg", doc.name
    v = doc.send :version
    assert ! v.new_record? , "Version is not a new record"
    assert_not_nil v.file_ref , "File_ref is set"
    data = doc.data
    assert_kind_of ImageFile , data
    assert_equal "661x600", "#{data.width}x#{data.height}"
    assert_equal "/jpg/#{doc.v_id}/birdy.jpg", data.path
    assert File.exist?("#{RAILS_ROOT}/data/test#{data.path}")
    assert_equal File.stat("#{RAILS_ROOT}/data/test#{data.path}").size, doc.filesize
    FileUtils::rmtree("#{RAILS_ROOT}/data/test") # clear files
  end
  
  def test_resize_image
    visitor(:ant)
    doc = secure(Image) { Image.create( :parent_id=>items_id(:cleanWater), 
                                        :inherit => 1,
                                        :name=>'birdy', :file => fixture_file_upload('/files/bird.jpg', 'image/jpeg')) }
    assert_kind_of Image , doc
    data = doc.data('pv')
    assert_kind_of ImageFile , data
    assert data.new_record? , "New record"
    assert_equal "80x80", "#{data.width}x#{data.height}"
    data.save # write image to disk
    assert_equal "/jpg/#{doc.v_id}/birdy-pv.jpg", data.path
    assert File.exist?("#{RAILS_ROOT}/data/test#{data.path}")
    assert_equal File.stat("#{RAILS_ROOT}/data/test#{data.path}").size, doc.filesize('pv')
    FileUtils::rmtree("#{RAILS_ROOT}/data/test") # clear files
  end
end
