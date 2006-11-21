# This class stores version text for #Document. If a translation or new redaction of the text
# is created, both the new and the old #DocVersion refer to the same file (#DocFile)
class DocVersion < Version
  validate :has_file
  validate_on_update :can_update_file

  after_create :create_doc_file
  before_update :update_file_ref
  
  # format is ignored here
  def img_tag(format=nil)
    unless format
      # img_tag from extension
      "<img src='/images/ext/#{item.ext}.png' width='30' height='30' class='tiny'/>"
    else
      img = ImageBuilder.new(:path=>"#{RAILS_ROOT}/public/images/ext/#{item.ext}.png", :width=>30, :height=>30)
      img.transform!(format)
      if img.dummy?
        if img.width < 30
          # only reduce size
          # let the browser resize
          "<img src='/images/ext/#{item.ext}.png' width='#{img.width}' height='#{img.height}' class='#{format}'/>"
        else
          "<img src='/images/ext/#{item.ext}.png' width='30' height='30' class='#{format}'/>"
        end
      else
        path = "#{RAILS_ROOT}/public/images/ext/"
        filename = "#{item.ext}-#{format}.png"
        unless File.exist?(File.join(path,filename))
          # make new image with the format
          unless File.exist?(path)
            FileUtils::mkpath(path)
          end
          File.open(File.join(path, filename), "wb") { |f| f.syswrite(img.read) }
        end
        "<img src='/images/ext/#{filename}' width='#{img.width}' height='#{img.height}' class='#{format}' />"
      end
    end
  end
  
  def doc_file
    @docfile ||= file_class.find_by_version_id(self[:file_ref])
  end
  alias file doc_file
  
  def filesize; file.size; end
    
  def file_ref=(i)
    raise Zena::AccessViolation, "'file_ref' cannot be changed"
  end
  
  def file=(f)
    @file = f
  end
  
  def title
    if self[:title] && self[:title] != ""
      self[:title]
    else
      item.doc_name
    end
  end
  
  private
  
  def set_file_ref
    self[:file_ref] ||= self[:id]
  end
  
  def has_file
    errors.add('file', 'not set') unless @file || doc_file
  end
  
  def can_update_file
    if @file && (self[:file_ref] == self[:id]) && (Version.find_all_by_file_ref(self[:id]).size > 1)
      errors.add('file', 'cannot be changed (used by other versions)')
    end
  end
  
  def create_doc_file
    unless doc_file
      # new document or new edition with a new file
      self[:file_ref] = self[:id]
      DocVersion.connection.execute "UPDATE versions SET file_ref=id WHERE id=#{id}"
      file_class.create(:version_id=>self[:id], :file=>@file)
    end
  end
  
  def update_file_ref
    if @file
      # redaction with a new file
      if self[:file_ref] == self[:id]
        # our own file changed
        doc_file.file = @file
        doc_file.save
      else
        self[:file_ref] = self[:id]
        file_class.create(:version_id=>self[:id], :file=>@file)
      end
    end
  end
  
  def file_class
    DocFile
  end
end
