module DocumentsHelper
  
  # Find the list of tabs for the popup when creating a new document. Any erb file found in
  # 'app/views/templates/document_create_tabs' starting with an underscore will be used.
  def form_tabs
    tabs = []
    help_file = nil
    Dir.entries(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'document_create_tabs')).sort.each do |file|
      next unless file =~ /^_(.*).rhtml$/
      if file == "_help.rhtml"
        help_file = file
      else
        tabs << $1
      end
    end
    tabs << 'help' if help_file
    tabs
  end
  
  def crop_formats(obj)
    buttons = ['jpg', 'png']
    ext = TYPE_TO_EXT[obj.c_conten_type]
    ext = ext ? ext[0] : obj.c_ext
    buttons << ext unless buttons.include?(ext)
    buttons.map do |e|
      "<input type='radio' name='node[c_crop][format]' value='#{e}'#{e==ext ? " checked='checked'" : ''}/> #{e} "
    end
  end
end
