=begin rdoc
TODO
=end
class Note < Item
  link :calendars, :class_name=>'Project'
  before_validation :set_log_at
  validate :parent_valid
  class << self
    def select_classes
      list = subclasses.inject([]) do |list, k|
        list << k.to_s
        list
      end.sort
      list.unshift 'Note'
    end
  end
  
  def klass
    self.class.to_s
  end
  
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
