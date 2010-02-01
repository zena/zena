require 'fileutils'
=begin rdoc
Used by Document and Image to store file data. See the documentation on these classes for more information.

=== Attributes

Provides the following attributes to Document and Image :

size::            file size
ext::             file extension
content_type::    file content_type
=end
class DocumentContent < ActiveRecord::Base

  # readable
  include RubyLess::SafeClass
  safe_method           :size => Number, :name => String, :content_type => String, :ext => String, :file => File

  # writable
  attr_accessible       :content_type, :file, :ext

  belongs_to            :site
  validate              :valid_file
  validate              :valid_content
  validates_presence_of :ext
  validates_presence_of :name
  before_validation     :content_before_validation
  before_save           :content_before_save
  after_save            :content_after_save
  before_destroy        :destroy_file

  # extend  Zena::Acts::Multiversion
  # act_as_content

  # protect access to size.
  def size=(s)
    raise StandardError, "Size cannot be set. It is defined by the file size."
  end

  def file=(file)
    @new_file = file
  end

  def clone
    new_obj = super
    new_obj.instance_variable_set(:@loaded_file, self.file)
    new_obj
  end

  def file(mode=nil)
    if mode.nil? && @new_file
      @new_file
    elsif File.exist?(filepath(mode))
      @loaded_file ||= File.new(filepath(mode))
    else
      raise IOError, "File not found"
    end
  end

  def changed?
    @new_file || super
  end


  def size(mode=nil)
    return self[:size] if self[:size]
    if !new_record? && File.exist?(filepath)
      self[:size] = File.stat(filepath).size
      self.save
    end
    self[:size]
  end

  # Path to store the data. The path is build with the version id so we can do the security checks when uploading data.
  def filepath(format=nil)
    raise StandardError, "Cannot build filepath for unsaved document_content." if new_record?
    mode   = format ? (format[:size] == :keep ? 'full' : format[:name]) : 'full'
    digest = Digest::SHA1.hexdigest(self[:id].to_s)
    # make sure name is not corrupted
    fname = name.gsub(/[^a-zA-Z\-_0-9]/,'')
    "#{SITES_ROOT}#{current_site.data_path}/#{mode}/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"
  end

  # Return true if this content is not used by any version.
  def can_destroy?
    0 == self.class.count_by_sql("SELECT COUNT(*) FROM versions WHERE id = #{self[:version_id]} OR content_id = #{self[:version_id]}")
  end

  # Return true if the version would be edited by the attributes
  def would_edit?(new_attrs)
    new_attrs.each do |k,v|
      if k == 'file'
        return true if (v.respond_to?(:size) ? v.size : File.size(v.path)) != self.size
        same = v.read(24) == self.file.read(24) && v.read == self.file.read
        v.rewind
        self.file.rewind
        return true if !same
      elsif type = self.class.safe_method_type([k])
        return true if field_changed?(k, self.send(type[:method]), v)
      end
    end
    false
  end

  private
    def valid_file
      return true if !new_record? || @new_file
      errors.add('file', "can't be blank")
      return false
    end

    def content_before_validation
      if @new_file
        self.content_type = @new_file.content_type.chomp
        if @new_file.kind_of?(StringIO)
          self[:size] = @new_file.size
        else
          self[:size] = @new_file.stat.size
        end

        if Zena::EXT_TO_TYPE[self.ext].nil? || !Zena::EXT_TO_TYPE[self.ext].include?(self.content_type)
          self.ext = @new_file.original_filename.split('.').last
        end
      end

      # is this extension valid ?
      extensions = Zena::TYPE_TO_EXT[content_type]
      if extensions && content_type != 'application/octet-stream' # use 'bin' extension only if we do not have any other ext.
        self[:ext] = (self.ext && extensions.include?(self.ext.downcase)) ? self.ext.downcase : extensions[0]
      else
        # unknown content_type or 'application/octet-stream' , just keep the extension we have
        self[:ext] ||= 'bin'
      end

      # set initial name from node
      self[:name] = version.node[:name].gsub('.','') if self[:name].blank?
    end

    def valid_content
      errors.add('version', "can't be blank") if !new_record? && can_destroy?
    end

    def content_before_save
      self[:type] = self.class.to_s # make sure the type is set in case no sub-classes are loaded.
    end

    def content_after_save

      if @new_file
        # destroy old file
        destroy_file unless @new_record_before_save

        # save new file
        make_file(filepath, @new_file)
      end
      # we are done with this file
      @new_file = nil
    end

    def make_file(path, data)
      FileUtils::mkpath(File.dirname(path)) unless File.exist?(File.dirname(path))
      File.open(path, "wb") { |f| f.syswrite(data.read) }
    end

    def destroy_file
      visitor.site.iformats.each do |k,v|
        next if k == :updated_at
        fpath = filepath(v)
        if File.exist?(fpath)
          FileUtils.rm(fpath)
          folder = File.dirname(fpath)
          if Dir.empty?(folder)
            # rm parent folder
            FileUtils::rmtree(folder)
            folder = File.dirname(folder)
            if Dir.empty?(folder)
              # rm parent / parent folder
              FileUtils::rmtree(folder)
            end
          end
        end
      end
    end
end
