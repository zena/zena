module DocumentHelper
  
  # Find the list of tabs for the popup when creating a new document. Any erb file found in
  # 'app/views/templates/document_create_tabs' starting with an underscore will be used.
  def form_tabs
    tabs = []
    help_file = nil
    Dir.foreach(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'document_create_tabs')).sort do |file|
      next unless file =~ /^_(.*).rhtml$/
      if file == "_help.rhtml"
        help_file = file
      else
        tabs << [trans($1), $1]
      end
    end
    tabs << [trans('help'), 'help'] if help_file
    tabs
  end
end
