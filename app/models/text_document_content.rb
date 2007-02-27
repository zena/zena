class TextDocumentContent < DocumentContent
  
  def file=(aFile)
    super
    version.text = @file.read
  end
  
  private
  
  def valid_file
    true # overwrite superclass behaviour
  end
  
  # called before_validation
  def prepare_filename
    # do nothing
  end
    
  # called before_save
  def prepare_content
    self[:type] = self.class.to_s # FIXME: this should not be needed... find another fix.
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
