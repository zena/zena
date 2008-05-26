require File.dirname(__FILE__) + '/../test_helper'

class ImageContentTest < ZenaTestUnit
  
  if Magick.const_defined?(:ZenaDummy)
    def test_set_file
      preserving_files('/test.host/data') do
        img = ImageContent.new(:version_id => versions_id(:bird_jpg_en))
        img.file = uploaded_jpg('bird.jpg')
        assert_nil img.width
        assert_nil img.height
        assert img.save, "Can save"
      end
    end
  else
    def test_set_file
      preserving_files('/test.host/data') do
        img = ImageContent.new(:name=>'bird', :version_id => versions_id(:bird_jpg_en))
        img[:site_id] = sites_id(:zena)
        img.file = uploaded_jpg('bird.jpg')
        assert_equal 660, img.width
        assert_equal 600, img.height
        assert img.save, "Can save"
      end
    end
  end
  
  def setup
    super
    @med = Iformat['med']
    @pv  = Iformat['pv']
  end
  
  def test_formats
    preserving_files('/test.host/data') do
      img = get_content(:bird_jpg)
      assert File.exist?(file_path(:bird_jpg)), "File exists"
      assert !File.exist?(file_path(:bird_jpg, 'pv')), "File does not exist"
      assert_equal 660, img.width
      assert_equal 70,  img.width(@pv)
      assert !File.exist?(file_path(:bird_jpg, 'pv')), "File does not exist"
      assert 2244 <= img.size(@pv) && img.size(@pv) <= 2246
      assert File.exist?(file_path(:bird_jpg, 'pv')), "File exist"
    end
  end
  
  def test_file_formats
    preserving_files('/test.host/data') do
      img = get_content(:bird_jpg)
      assert File.exist?(file_path(:bird_jpg)), "File exists"
      assert !File.exist?(file_path(:bird_jpg, 'pv') ), "File does not exist"
      assert !File.exist?(file_path(:bird_jpg, 'med')), "File does not exist"
      assert img.file
      assert img.file(@pv)
      assert img.file(@med)
      assert File.exist?(file_path(:bird_jpg, 'pv')  ), "File exist"
      assert File.exist?(file_path(:bird_jpg, 'med')), "File exist"
    end
  end
  
  def test_remove_formatted_on_file_change
    preserving_files('/test.host/data') do
      img  = get_content(:bird_jpg)
      assert img.file(@pv)  # create image with 'pv'  format
      assert img.file(@med) # create image with 'med' format
      # we have 3 files now
      assert File.exist?(img.filepath       ), "File exist"
      assert File.exist?(img.filepath(@pv) ), "File exist"
      assert File.exist?(img.filepath(@med)), "File exist"
      # change file
      img.file = uploaded_jpg('flower.jpg')
      assert img.save, "Can save"
      assert File.exist?(img.filepath       ), "File exist"
      assert !File.exist?(img.filepath(@pv) ), "File does not exist"
      assert !File.exist?(img.filepath(@med)), "File does not exist"
      
      # change name no longer changes file names
      old_path = img.filepath
      img.file(@med) # create image with 'med' format
      med_path  = img.filepath(@med)
      assert File.exist?(  med_path          ), "File exist"
      node = secure!(Node) { nodes(:bird_jpg) }
      node.name = 'new'
      img = node.version.content
      assert node.save, "Can save"
      assert File.exist?(  old_path         ), "File exist"
      assert File.exist?(  med_path         ), "File exist"
    end
  end
  
  def test_remove_mode_image
    preserving_files('/test.host/data') do
      img  = get_content(:bird_jpg)
      assert img.file(@pv)  # create image with 'pv'  format
      assert img.file(@med) # create image with 'med' format
      # we have 3 files now
      assert File.exist?(img.filepath      ), "File exist"
      assert File.exist?(img.filepath(@pv) ), "File exist"
      assert File.exist?(img.filepath(@med)), "File exist"
      # remove file
      img.file = uploaded_jpg('flower.jpg')
      assert img.save
      assert File.exist?(img.filepath       ), "File exist"
      assert !File.exist?(img.filepath(@pv) ), "File does not exist"
      assert !File.exist?(img.filepath(@med)), "File does not exist"
    end
  end
  
  private
    def get_content(sym)
      login(:ant) unless @visitor
      doc = secure!(Document) { Document.find(nodes_id(sym)) }
      doc.version.content
    end
end
