module NodeHelper

  # Find the list of tabs for the popup when 'driving' a node. To add a tab for some document class,
  # create a file named '_any_className.rhtml' in the folder 'app/views/templates/drive_tabs'.
  # If you want this tab to be used only for a certain skin, use the name '_skinName_className.rhtml'.
  def form_tabs
    tabs = []
    skin = @node.skin || 'default'
    tabs = [[trans('drive'),'drive'],[trans('links'),'links']]
    ["#{skin}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}"].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'drive_tabs', "_#{filename}.rhtml"))
        tabs << [trans(@node.class.to_s.downcase), filename]
        break
      end
    end
    tabs << [trans('help'),'help']
    tabs
  end
end
