
module Zena
  module Use

    # The attachement module provides shared file attachments to a class with a copy-on-write
    # pattern.
    # Basically the module provides 'file=' and 'file' methods.
    module SharedAttachment
      module ClassMethods
        def set_attachment_class(class_name)
          belongs_to :attachment,
                     :class_name => class_name,
                     :foreign_key => 'attachment_id'
        end
      end

      def self.included(base)
        base.class_eval do
          before_create  :save_attachment
          before_update  :attachment_before_update
          before_destroy :attachment_before_destroy

          extend Zena::Use::SharedAttachment::ClassMethods
          set_attachment_class 'Zena::Use::SharedAttachment::Attachment'
        end
      end

      def file=(file)
        if attachment
          @attachment_to_unlink = self.attachment
          self.attachment = nil
        end
        @attachment_need_save = true
        self.build_attachment(:file => file)
      end

      def filepath
        attachment ? attachment.filepath : nil
      end

      private
        def save_attachment
          if @attachment_need_save
            @attachment_need_save = nil
            attachment.save
          else
            true
          end
        end

        def attachment_before_update
          if @attachment_to_unlink
            @attachment_to_unlink.unlink(self)
            @attachment_to_unlink = nil
          end
          save_attachment
        end

        def attachment_before_destroy
          if attachment = self.attachment
            attachment.unlink(self)
          else
            true
          end
        end

        def unlink_attachment_mark
          @attachment_to_unlink = self.attachment
        end

        def unlink_attachment
        end


    end # SharedAttachment
  end # Use
end # Zena