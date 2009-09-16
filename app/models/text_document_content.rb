class TextDocumentContent < DocumentContent

  def file=(aFile)
    super
    version.text = @file.read
  end

  def file(mode=nil)
    @file ||= StringIO.new(version.text)
  end

  # Return document file size (= version's text size).
  def size(format=nil)
    version.text.size
  end

  def filename
    version.node.filename
  end

  private

  def valid_file
    true # overwrite superclass behaviour
  end

  # called before_save. Replace behaviour of TextDocuments.
  def content_before_save
    self[:type] = self.class.to_s # make sure the type is set in case no sub-classes are loaded.

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
