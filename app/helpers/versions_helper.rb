module VersionsHelper
  # Find the list of tabs for the popup when editing a node. To add a tab for some document class,
  # create a file named '_ClassName.rhtml' in the folder 'app/views/templates/edit_tabs'.
  def form_tabs
    tabs  = ['text', 'title']
    klass = @node.class.to_s.downcase
    tabs << klass if File.exists?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'edit_tabs', '_' + klass + '.rhtml'))
    tabs << 'help'
  end
end