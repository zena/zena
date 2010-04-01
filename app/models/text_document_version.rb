=begin rdoc
This is the version used by TextDocument. It behave exactly like its superclass (DocumentVersion) except for the content class, set to TextDocumentContent.
=end

class TextDocumentVersion < DocumentVersion
  class AssetHelper
    attr_accessor :visitor
    include Zena::Acts::Secure            # secure
    include Zena::Use::Zazen::ViewMethods # make_image, ...
    include Zena::Use::ZafuTemplates::Common       # template_url_for_asset
    include Zena::Use::Urls::Common       # data_path
  end

  before_save :parse_assets_before_save

  def self.content_class
    TextDocumentContent
  end

  private
    def parse_assets_before_save
      if text_changed? && content.content_type == 'text/css'
        helper = AssetHelper.new
        helper.visitor = visitor
        self.text = node.parse_assets(self.text, helper, 'v_text')
      end
    end

end
