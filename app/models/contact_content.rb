=begin rdoc
Used by Contact to store contact data. See the documentation on this class for more information.

=== Attributes

Provides the following attributes to Contact :

first_name:: first name
name::       name
address::    address (text)
zip::        zip code
city::       city name
telephone::  phone number
mobile::     mobile phone number
email::      email address
birthday::   birthday (date)
=end
class ContactContent < ActiveRecord::Base
  
  zafu_readable      :created_at, :updated_at, :fullname, :initials, :first_name, :name, :address, :zip, :city,
                     :telephone, :mobile, :email

  
  belongs_to :version
  before_validation :content_before_validation
  
  # Full contact name to show in views.
  def fullname
    (!first_name.blank? && !name.blank?) ? (first_name + " " + name) : (first_name || name)
  end
  
  # First letters of the first_name and the name in capitals (ex. GB).
  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
  
  private
  def content_before_validation
    self[:site_id] = version.node[:site_id]
    [:first_name, :name, :address, :zip, :city, :telephone, :mobile, :email].each do |sym|
      self[sym] ||= ""
    end
  end
end
