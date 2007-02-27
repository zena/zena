module VersionHelper
  def form_tabs(mode=:edit)
    tabs = []
    case mode
    when :edit
      tmplt = @node.skin || 'default'
      tabs = [[trans('text'),'text'],[trans('title'),'title'],[trans('help'),'help']]
      ["#{tmplt}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}"].each do |filename|
        if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'edit_tabs', "_#{filename}.rhtml"))
          tabs << [trans(@node.class.to_s.downcase), filename]
          break
        end
      end
    when :create
      Dir.foreach(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'create_tabs')) do |file|
        next unless file =~ /^_(.*).rhtml$/
        tabs << [trans($1), $1]
      end
    end
    tabs
  end
end
