require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'
class DocumentTest < Test::Unit::TestCase
  include ZenaTestUnit


  def test_create_with_file
    visitor(:ant)
    doc = secure(Document) { Document.create( :parent_id=>items_id(:cleanWater),
                                              :inherit => 1,
                                              :name=>'report', 
                                              :file => fixture_file_upload('/files/water.pdf', 'application/pdf')) }
    assert_kind_of Document , doc
    assert ! doc.new_record? , "Not a new record"
    assert_equal "report.pdf", doc.name
    assert_equal "report", doc.title
    v = doc.send :version
    assert ! v.new_record? , "Version is not a new record"
    assert_not_nil v.file_ref , "File_ref is set"
    data = doc.data
    assert_kind_of DocFile , data
    assert_equal "/pdf/#{doc.v_id}/report.pdf", data.path
    assert File.exist?("#{RAILS_ROOT}/data/test#{data.path}")
    assert_equal File.stat("#{RAILS_ROOT}/data/test#{data.path}").size, doc.filesize
    FileUtils::rmtree("#{RAILS_ROOT}/data/test") # clear files
  end
  
  def get_with_full_path
    visitor(:tiger)
    doc = secure(Document) { Document.find_by_path( user_id, user_groups, lang, "/projects/cleanWater/water.pdf") }
    assert_kind_of Document, doc
    assert_equal "/projects/cleanWater/water.pdf", doc.fullpath
  end
end
