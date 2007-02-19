class Template < TextDocument
  class << self
    # Return the best template for the current :mode, :class and :template. Must be used within 'secure' scope.
    def best_match(opts={})
      mode  = opts[:mode]
      mode  = nil if (mode.nil? || mode == '')
      klass = opts[:class] ? opts[:class].to_s.downcase : nil
      tmpl  = opts[:template]
      template = nil
      choices = []
      #                          (mode / template / class)
      #   1. template_class_mode (111)
      choices << "#{tmpl}_#{klass}_#{mode}" if mode && tmpl && klass
      #   2. template__mode      (110)
      choices << "#{tmpl}__#{mode}" if mode && tmpl
      #   3. default_class_mode  (101)
      choices << "default_#{klass}_#{mode}" if mode && klass
      #   4. default__mode       (100)
      choices << "default__#{mode}" if mode
      #   5. template_class      ( 11)
      choices << "#{tmpl}_#{klass}" if tmpl && klass
      #   6. template            ( 10)
      choices << tmpl if tmpl
      #   7. default_class       (  1)
      choices << "default_#{klass}" if klass
      #   8. default             (  0)
      choices << "default"
      choices.each do |template_name|
        # we are in secure scope already
        break if template = Template.find_by_name(template_name)
      end
      return template
    end
  end 
  
  # opts can be :mode and :klass
  def template_url(helper)
    temp_url = "#{self[:name]}_#{visitor_lang}"
    
    # 2. does the file for the current lang exist ?
    path = File.join(RAILS_ROOT, 'app', 'views', 'templates', "#{temp_url}.rhtml")
    if File.exist?(path) && (File.stat(path).mtime > version.updated_at)
      # we are done
      return "/templates/#{temp_url}"
    end
    # render for the current lang
    res = ZafuParser.new(version.text, :helper=>helper).render
    File.open(path, "wb") { |f| f.syswrite(res) }
    return "/templates/#{temp_url}"
  end
end
