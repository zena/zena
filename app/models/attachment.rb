require 'versions'

class Attachment < Versions::SharedAttachment

  before_save   :set_visitor_id, :set_site_id
  after_destroy :destroy_iformats

  def filepath(format=nil)
    mode   = format ? (format[:size] == :keep ? 'full' : format[:name]) : 'full'
    "#{SITES_ROOT}#{current_site.data_path}/#{mode}/#{super()}"
  end

  def remove_file
    FileUtils.rm(filepath) if File.exist?(filepath)
  end

  private
    def set_visitor_id
      self['user_id'] = visitor.id
    end

    def set_site_id
      self['site_id'] = current_site.id
    end

    # When destoying an image, make sur to delete all iformats and their corresponding folders.
    def destroy_iformats
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