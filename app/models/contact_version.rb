=begin rdoc
This class stores version text for BaseContact. See Version for details.

=== Content

Uses ContactContent.
=end
class BaseContactVersion < Version

  def self.content_class
    ContactContent
  end

  def redaction_content
    @old_fullname ||= content.fullname
    super
  end

  private
    def version_before_validation
      if title.blank?
        self.title = content.fullname
      elsif content.fullname.blank?
        if title =~ /^(\S+)\s+(.*)$/
          content.first_name = $1
          content.name = $2
        else
          content.name = title
        end
      end

      if title_changed? && content.fullname_changed?
        # ignore if both title and fullname changed
      elsif content.fullname_changed? && title == content.fullname_was
        # fullname changed and title was in sync
        self.title = content.fullname
      end
      super
    end
end
