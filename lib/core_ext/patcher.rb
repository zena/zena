def foreach_brick(&block)
  bricks_folder = File.join(RAILS_ROOT, 'bricks')
  Dir.entries(bricks_folder).sort.each do |brick|
    next if brick =~ /\A\./
    block.call(File.join(bricks_folder, brick))
  end
end

def load_patches_from_bricks
  file_name = caller[0].split('/').last.split(':').first
  foreach_brick do |brick_path|
    patch_file = File.join(brick_path, 'patch', file_name)
    if File.exist?(patch_file)
      load patch_file
    end
  end
end

def load_models_from_bricks
  # make sure native models are loaded first
  foreach_brick do |brick_path|
    models_path = File.join(brick_path, 'models')
    next unless File.exist?(models_path)
    Dir.foreach(models_path) do |model_name|
      next if model_name =~ /\A\./
      eval model_name[/(\w+)\.rb/,1].capitalize.url_name
    end
  end
end

def load_zafu_rules_from_bricks
  foreach_brick do |brick_path|
    zafu_path = File.join(brick_path, 'zafu')
    next unless File.exist?(zafu_path)
    Dir.foreach(zafu_path) do |rules_name|
      next if rules_name =~ /\A\./
      load File.join(zafu_path, rules_name)
    end
  end
end