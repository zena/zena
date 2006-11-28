class ContactContent < ActiveRecord::Base
  
  # Full contact name to show in views.
  def fullname
    first_name + " " + name
  end
  
  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
end
