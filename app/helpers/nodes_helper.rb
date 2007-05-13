module NodesHelper

  def dummy
    _('drive') # gettext
    _('links') # gettext
  end
  # Find the list of tabs for the popup when 'driving' a node. To add a tab for some document class,
  # create a file named '_any_className.rhtml' in the folder 'app/views/templates/drive_tabs'.
  # If you want this tab to be used only for a certain skin, use the name '_skinName_className.rhtml'.
  # Return a list in the form [name, filename], [name, ...], ...
  def form_tabs
    tabs = []
    skin = @node.skin || 'default'
    tabs = [['drive','drive'],['links','links']]
    ["#{skin}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}"].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'drive_tabs', "_#{filename}.rhtml"))
        tabs << [@node.class.to_s.downcase, filename]
        break
      end
    end
    tabs << ['help','help']
    tabs
  end
end
