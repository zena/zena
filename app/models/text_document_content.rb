class TextDocumentContent < DocumentContent
  
  def file=(aFile)
    super
    version.text = @file.read
  end
  
  # Return document file size (= version's text size). Implemented as 'c_size' in TextDocument.
  def size(format=nil)
    0
  end
  
  private
  
  def valid_file
    true # overwrite superclass behaviour
  end
  
  # called before_save
  def content_before_save
    super
    if @file
      # nothing to do
    elsif !new_record? && (old = DocumentContent.find(self[:id])).name != self[:name]
      # TODO: clear cache
    end
  end
  
  def make_file(path, data)
    # TODO: raise error
  end
  
  def destroy_file
    # TODO: clear cache
    # TODO: set content_id of versions whose content_id was self[:version_id]
  end
end
