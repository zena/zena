=begin rdoc
TODO
=end
class Note < Node
  link :calendars, :class_name=>'Project'
  link :projects,  :class_name=>'Project'
  
  before_validation :prepare_note
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
  
  def name=(str)
    super
    @name_set = true
  end
  
  private
  
  def prepare_note
    self[:log_at]   ||= Time.now.utc
    self[:event_at] ||= self[:log_at]
    self.name = version.title unless self[:name]
    self[:name] = "#{log_at.year}-#{log_at.month}-#{log_at.day}-#{name}" if @name_set
  end
end
