module VersionHelper
  def form_tabs
    tmplt = @node.template || 'default'
    tabs = [['text','text'],['title','title'],['help','help']]
    ["#{tmplt}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}"].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'form_tabs', "_#{filename}.rhtml"))
        tabs << [@node.class.to_s.downcase, filename]
        break
      end
    end
    return tabs
  end
end
