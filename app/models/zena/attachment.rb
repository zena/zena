module Zena
  class Attachment < Zena::Use::SharedAttachment::Attachment
    # Path to store the data. The path is build with the version id so we can do the security checks when uploading data.
    def filepath(format=nil)
      raise StandardError, "Cannot build filepath for unsaved attachment." if new_record?
      mode   = format ? (format[:size] == :keep ? 'full' : format[:name]) : 'full'
      File.join(SITES_ROOT, current_site.data_path, mode, super())
    end

    private
      def remove_file
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
end