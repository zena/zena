module Zena
  module Use
    module SharedAttachment
      class Attachment < ActiveRecord::Base
        set_table_name 'attachments'
        after_destroy :remove_file
        after_save    :write_file

        def unlink(model)
          link_count = model.class.count(:conditions => ["attachment_id = ? AND id != ?", self.id, model.id])
          if link_count == 0
            destroy
          end
        end

        def file=(file)
          @file = file
          self[:filename] = get_filename(file)
        end

        def filepath
          @filepath ||= begin
            digest = Digest::SHA1.hexdigest(self[:id].to_s)
            "#{digest[0..0]}/#{digest[1..1]}/#{filename}"
          end
        end

        private
        def write_file
          # FIXME: implement the after_commit hook
          #current_transaction.after_commit do
          make_file(filepath, @file)
          #end
        end

        def destroy_file
          # FIXME: implement the after_commit hook
          #current_transaction.after_commit do
          remove_file
          #end
        end

        def make_file(path, data)
          FileUtils::mkpath(File.dirname(path)) unless File.exist?(File.dirname(path))
          if data.respond_to?(:rewind)
            data.rewind
          end
          File.open(path, "wb") { |f| f.syswrite(data.read) }
        end

        def remove_file
          FileUtils.rm(filepath)
        end

        def get_filename(file)
          # make sure name is not corrupted
          fname = file.original_filename.gsub(/[^a-zA-Z\-_0-9\.]/,'')
          if fname[0..0] == '.'
            # Forbid names starting with a dot
            fname = Digest::SHA1.hexdigest(Time.now.to_i.to_s)[0..6]
          end
          fname
        end
      end # Attachment
    end # SharedAttachment
  end # Use
end # Zena
