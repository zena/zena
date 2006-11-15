class Image < Document

  def file(format=nil)
    version.file(format)
  end
  def filesize(format=nil)
    version.filesize(format)
  end
  private
  # This is a callback from acts_as_multiversioned
  def version_class
    ImageVersion
  end
end
