module VersionHelper
  
  # Find the list of tabs for the popup when editing a node. To add a tab for some document class,
  # create a file named '_any_className.rhtml' in the folder 'app/views/templates/edit_tabs'.
  # If you want this tab to be used only for a certain skin, use the name '_skinName_className.rhtml'.
  def form_tabs
    tabs = []
    skin = @node.skin || 'default'
    tabs = [['text','text'],['title','title']]
    ["#{skin}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}"].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'edit_tabs', "_#{filename}.rhtml"))
        tabs << [@node.class.to_s.downcase, filename]
        break
      end
    end
    tabs << ['help','help']
    tabs
  end
end
