=begin rdoc
A note is a 'dated' element. It is typically used for blog entries or/and calendar events.

=== dates

On top of the Node's dates (+created_at+, +updated_at+, +publish_from+), a note uses the following:

log_at::    used to sort/display blog entries
event_at::  used in calendars

These two dates enable you to announce an event in the blog list a couple of days before it actually occurs (event_at). All dates are stored internally as 'utc' and are converted to/from the visitor's current timezone.

=== links

Default links for Notes are:

calendars::  make this note appear in the given calendar (there is one calendar per project). By default the note is not included in its project's calendar.
projects::   make this note appear in the blog of the given project. A note always appear in its project.

=== subclasses

Letter::     like the name says...

=== subclasses to implement before 1.0
Todo::       manage things to be done (parent = Note = Todo). The parent provides the 'due date'.
Request::    subclass of Todo. Manage user/client requests.
Bug::        (the class we most need!). subclass of Request.
Milestone::  special event used when choosing a Request/Bug's parent.
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
  
  private
  
  def prepare_note
    self[:log_at]   ||= Time.now
    self[:event_at] ||= self[:log_at]
    self.name = version.title unless self[:name]
  end
end
