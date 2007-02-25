class Template < TextDocument
  
  # TODO: test
  def sweep_cache
    super
    if self.kind_of?(Skin)
      tmpl = "#{name}/any"
    else
      tmpl = "#{parent[:name]}/#{name}"
    end
    ZENA_ENV[:languages].each do |lang|
      filepath = File.join(RAILS_ROOT,'app', 'views', 'templates', 'compiled')
      filepath = "#{filepath}/#{tmpl}_#{lang}.rhtml"
      if File.exist?(filepath)
        File.delete(filepath)
      end
    end
  end
end
