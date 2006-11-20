# TODO: Users = own table. Addresse = same status as DocFile: linked to ContactVersion. Cache 'fullname' and 'email' into User through User.Contact.fullname, User.Contact.email
class Address < ActiveRecord::Base
  belongs_to :item, :dependent=>:destroy # contact, place
  before_create :set_lang
  before_update :set_lang
  
  # Full contact name to show in views.
  def fullname
    first_name + " " + name
  end
  
  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
  
  def first_name
    self[:first_name] || ""
  end
  def name
    self[:name] || ""
  end
  def mobile
    self[:mobile] || ""
  end
  def address
    self[:address] || ""
  end
  def telephone
    self[:telephone] || ""
  end
  def zip
    self[:zip] || ""
  end
  def city
    self[:city] || ""
  end
  def email
    self[:email] || ""
  end
  # birthday can be nil
  
  private
  # Prefered language must be set. It is set to the applicatin default if none was given.
  def set_lang #:doc:
    unless (self.lang and self.lang != "")
      self.lang= ZENA_ENV[:default_lang]
    end
  end
end
