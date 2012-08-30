# A skin is a container for templates and css to render a full site or sectioon
# of a site.
class Skin < Section
  def skin_name
    title.to_filename
  end
end