=begin rdoc
This is the version used by TextDocument. It behave exactly like its superclass (DocumentVersion) except for the content class, set to TextDocumentContent.
=end
class TextDocumentVersion < DocumentVersion
  before_save :parse_assets_before_save

  def self.content_class
    TextDocumentContent
  end

  private
    def parse_assets_before_save
      if text_changed? && content.content_type == 'text/css'
        # Dummy controller so we have access to urls. Any better idea gladly welcome.
        helper = ApplicationController.new
        helper.instance_variable_set(:@visitor, visitor)
        self.text = node.parse_assets(self.text, helper, 'v_text')
      end
    end

end
