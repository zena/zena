module ActionController #:nodoc:
  module Layout #:nodoc:
    def find_layout(layout, format, html_fallback=false) #:nodoc:
      view_paths.find_template(layout.to_s =~ /\A\/|layouts\// ? layout : "layouts/#{layout}", format, html_fallback)
    rescue ActionView::MissingTemplate
      raise if Mime::Type.lookup_by_extension(format.to_s).html?
    end
  end
end