=begin rdoc
TODO
=end
class Note < Item
  def initialize(*args)
    super(*args)
    self[:blog_at] ||= Time.now
    self
  end
  
  def validate_on_create
    super
    return unless errors.empty?
    # make sure parent is a Project
    errors.add("parent_id", "invalid parent") unless parent.kind_of?(Project)
  end
  
  def validate_on_update
    super
    return unless errors.empty?
    # make sure parent is a Project
    errors.add("parent_id", "invalid parent") unless parent.kind_of?(Project)
  end
  
  # Return the full path as an array if it is cached or build it when asked for.
  def name_for_fullpath
    d = blog_at || created_at
    "#{d.year}-#{d.month}-#{d.day}-#{name}"
  end
end
