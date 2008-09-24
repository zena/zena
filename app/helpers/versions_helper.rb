module VersionsHelper
  # Find the list of tabs for the popup when editing a node. To add a tab for some document class,
  # create a file named '_ClassName.rhtml' in the folder 'app/views/templates/edit_tabs'.
  def form_tabs
    tabs  = ['text', 'title']
    klass = nil
    @node.class.ancestors.map { |a| a.to_s.downcase }.each do |k|
      if File.exists?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'edit_tabs', '_' + k + '.rhtml'))
        klass = k
        break
      end
      break if k == 'node'
    end
    tabs << klass if klass
    tabs << 'custom'
    tabs << 'help'
  end
end