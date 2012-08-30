# A skin is a container for templates and css to render a full site or sectioon
# of a site.
class Skin < Section
  def skin_name
    title.to_filename
  end
  
  def self.text_from_fs_skin(brick_name, skin_name, path, opts)
    # dummy implementation
    nil
  end
end