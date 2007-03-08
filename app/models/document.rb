=begin rdoc
TODO: on name change make sure content name changes too...
=end
class Document < Page
  before_validation :prepare_before_validation
  
  class << self
    def parent_class
      Node
    end
    
    alias o_create create
    def create(hash)
      scope = self.scoped_methods[0] || {}
      klass = self
      if hash[:c_file]
        content_type = hash[:c_file].content_type
      elsif hash[:c_content_type]
        content_type = hash[:c_content_type]
      elsif hash[:name] =~ /^.*\.(\w+)$/ && types = EXT_TO_TYPE[$1]
        content_type = types[0]
      else
        content_type = 'text/plain'
      end
      if Image.accept_content_type?(content_type)
        klass = Image
      elsif Template.accept_content_type?(content_type)
        if hash[:parent_id] && Node.find(hash[:parent_id]).kind_of?(Skin)
          klass = Template
        else
          klass = Skin
        end
      elsif TextDocument.accept_content_type?(content_type)
        klass = TextDocument
      else
        klass = Document
      end
      klass.with_scope(scope) { klass.o_create(hash) }
    end
  end
  
  def c_file=(file)
    @file = file
  end
  
  def image?
    kind_of?(Image)
  end
  
  def filename
    "#{name}.#{version.content.ext}"
  end
  
  def img_tag(format=nil, opts={})
    version.content.img_tag(format, opts)
  end
  
  private
  
  # Set name from filename
  def prepare_before_validation
    content = version.content
    if new_record?
      if self[:name] && self[:name] != ""
        base = self[:name]
      elsif @file
        base = @file.original_filename
      end
      if base =~ /\./
        self[:name] = base.split('.')[0..-2].join('.')
        ext  = base.split('.').last
      end
      content[:name] = self[:name]
      content[:ext] = self[:ext]
    else
      # when cannot use 'old' here as this record is not secured when spreading inheritance
      if self[:name] != self.class.find(self[:id])[:name] && self[:name] && self[:name] != ''
        # update all content names :
        versions.each do |v|
          content = v.content
          content.name = self[:name]
          content.save
        end
      end
    end
      
    if @file
      # set file
      version.redaction_content.file = @file
    end
  end
  
  # Sweep cached data for the document
  # TODO: test 
  def sweep_cache
    super
    # Remove cached data from the public directory.
    versions.each do |v|
      next if v[:content_id]
      FileUtils::rmtree(File.dirname(v.content.cachepath))
    end
  end

  # This is a callback from acts_as_multiversioned
  def version_class
    DocumentVersion
  end
end