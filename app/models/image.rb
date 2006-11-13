class Image < Document

  def data(format=nil)
    version.data(format)
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
