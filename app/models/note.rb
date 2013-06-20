=begin rdoc
This class is not really useful anymore since 'event_at' and 'log_at' are obsolete. This class is really used for
testing having a virtual class 'Note' with a real ruby class of the same Name.
=end
class Note < Node
  
  class << self

    def select_classes
      list = subclasses.inject([]) do |list, k|
        next if k.to_s == 'Post'
        list << k.to_s
        list
      end.sort
      list.unshift 'Post'
    end
  end

  def export_keys
    h = super
    h[:dates].merge!('log_at' => log_at) unless log_at.blank?
    h[:dates].merge!('event_at' => event_at) unless event_at.blank?
    h
  end

  private

  def set_defaults
    super
    self[:log_at]   ||= self[:event_at] || Time.now
    self[:event_at] ||= self[:log_at]
  end
end
