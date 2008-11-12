def foreach_plugin(&block)
  plugins_folder = File.join(RAILS_ROOT, 'vendor', 'plugins')
  Dir.foreach(plugins_folder) do |plugin|
    next if plugin =~ /\A\./
    block.call(File.join(plugins_folder, plugin))
  end
end

def load_patches_from_plugins
  file_name = caller[0].split('/').last.split(':').first
  foreach_plugin do |plugin_path|
    patch_file = File.join(plugin_path, 'patch', file_name)
    if File.exist?(patch_file)
      load patch_file
    end
  end
end

def load_models_from_plugins
  foreach_plugin do |plugin_path|
    Dir.foreach(File.join(plugins_path, 'models')) do |model_name|
      load File.join(plugins_path, 'models', model_name)
    end
  end
end