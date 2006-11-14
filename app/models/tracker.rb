=begin rdoc
=== What is a Tracker ?
It's a page that stores bugs and actions. There is also a #Link to a 'client' and with all this together, you
can #Invoice your work !! (nice, isn't it ?)

It also helps to keep projects organized with ticket ids and so on.
=end
class Tracker < Page
  # used to build kpath, as T is used for Tags, we use 'A'
  def self.ksel
    self == Tracker ? 'A' : super
  end
end
