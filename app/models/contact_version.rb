=begin rdoc
This class stores version text for Contact. See Version for details.

=== Content

Uses ContactContent.
=end
class ContactVersion < Version
  before_validation :contact_version_before_validation
  
  def self.content_class
    ContactContent
  end
  
  def redaction_content
    @old_fullname ||= content.fullname
    super
  end
  
  private
    def contact_version_before_validation
      if self.title.blank?
        self.title = content.fullname 
      elsif content.fullname.blank?
        if self.title =~ /^(\S+)\s+(.*)$/
          content.first_name = $1
          content.name = $2
        else
          content.name = self.title
        end
      end
      
      old_title = node.old_title
      return true if old_title.nil?
      # what changed ?
      title_changed    = title            != old_title
      fullname_changed = content.fullname != @old_fullname
      # 1. both
      if title_changed && fullname_changed
        # ignore
      elsif fullname_changed && node.old_title == @old_fullname
        # content changed and title was in sync
        self.title = content.fullname
      end
    end
end
