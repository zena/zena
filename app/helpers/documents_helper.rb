module DocumentsHelper

  # Find the list of tabs for the popup when creating a new document. Any erb file found in
  # 'app/views/templates/document_create_tabs' starting with an underscore will be used.
  def form_tabs
    tabs = []
    Dir.entries(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'document_create_tabs')).sort.each do |file|
      next unless file =~ /^_(.*).rhtml$/
      tabs << $1
    end
    tabs
  end
end
