require File.dirname(__FILE__) + '/../test_helper'

class DocFileTest < Test::Unit::TestCase
  include ZenaTestUnit

  def bird
    File.join(File.dirname(__FILE__), '../fixtures/files/bird.jpg')
  end
  def water
    File.join(File.dirname(__FILE__), '../fixtures/files/water.pdf')
  end
  
  def test_set_file
    doc = DocFile.new
    assert_nothing_raised { doc.file = uploaded_pdf(water) }
  end
  #Errno::ENOENT
  def test_read
    doc = DocFile.new( :file=>uploaded_pdf(water) )
    assert_nothing_raised { doc.read }
  end
end
