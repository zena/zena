class ContactContent < ActiveRecord::Base
  belongs_to :version
  before_validation :content_before_validation
  
  # Full contact name to show in views.
  def fullname
    first_name + " " + name
  end
  
  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
  
  private
  def content_before_validation
    self[:site_id] = version.node[:site_id]
  end
end
