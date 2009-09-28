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
  act_as_content
  attr_public        :created_at, :updated_at, :fullname, :initials, :first_name, :name, :address, :zip, :city,
                     :telephone, :mobile, :email, :country
  attr_protected     :site_id
  after_initialize   :set_contact_content_defaults
  before_validation  :content_before_validation

  # Full contact name to show in views.
  def fullname(first_name = self.first_name, name = self.name)
    (!first_name.blank? && !name.blank?) ? (first_name + " " + name) : (first_name.blank? ? name : first_name)
  end

  # First letters of the first_name and the name in capitals (ex. GB).
  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end

  # Return true if this content is not used by any version.
  def can_destroy?
    0 == self.class.count_by_sql("SELECT COUNT(*) FROM versions WHERE id = #{self[:version_id]} OR content_id = #{self[:version_id]}")
  end

  def fullname_was
    fullname(first_name_changed? ? first_name_was : self.first_name, name_changed? ? name_was : self.name)
  end

  def fullname_changed?
    first_name_changed? || name_changed?
  end

  def attributes_with_defaults=(attrs)
    self.attributes_without_defaults = attrs
    %W{address}.each do |txt_field|
      self[txt_field] ||= ''
    end
  end
  alias_method_chain :attributes=, :defaults

  private
    def content_before_validation
      self[:site_id] = version.node[:site_id]
      [:first_name, :name, :address, :zip, :city, :telephone, :mobile, :email].each do |sym|
        self[sym] ||= ""
      end
    end
end
