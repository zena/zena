def load_patches_from_plugins
  file_name = caller[0].split('/').last.split(':').first
  plugins_folder = File.join(RAILS_ROOT, 'vendor', 'plugins')
  Dir.foreach(plugins_folder) do |plugin|
    next if plugin =~ /\A\./
    patch_file = File.join(plugins_folder, plugin, 'patch', file_name)
    if File.exist?(patch_file)
      load patch_file
    end
  end
end