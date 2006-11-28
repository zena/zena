=begin rdoc
TODO
=end
class Note < Item
  link :diaries, :class_name=>'Project', :as=>'diary'
  
  before_validation :set_log_at
  validate :parent_valid
  
  # Return the full path as an array if it is cached or build it when asked for.
  def name_for_fullpath
    "#{log_at.year}-#{log_at.month}-#{log_at.day}-#{name}"
  end
  
  private
  
  def set_log_at
    self[:log_at] ||= Time.now
  end
  
  def parent_valid
    errors.add("parent_id", "invalid parent") unless parent.kind_of?(Project)
  end
end
