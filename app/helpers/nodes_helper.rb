module NodesHelper
  # Find the list of tabs for the popup when 'driving' a node. To add a tab for some document class,
  # create a file named '_any_className.rhtml' in the folder 'app/views/templates/drive_tabs'.
  # If you want this tab to be used only for a certain skin, use the name '_skinName_className.rhtml'.
  # Return a list in the form [name, filename], [name, ...], ...
  def form_tabs
    tabs = ['drive','links']
    klass = nil
    @node.class.ancestors.map { |a| a.to_s.downcase }.each do |k|
      if File.exists?(File.join(Zena::ROOT, 'app', 'views', 'templates', 'drive_tabs', '_' + k + '.rhtml'))
        klass = k
        break
      end
      break if k == 'node'
    end
    tabs << klass if klass
    tabs << 'help'
    tabs
  end
end
