=begin rdoc
TODO
=end
class Note < Item
  link :calendars, :class_name=>'Project'
  before_validation :set_dates
  class << self
    def parent_class
      Project
    end
    
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
  
  def set_dates
    self[:log_at]   ||= Time.now
    self[:event_at] ||= self[:log_at]
  end
end
