=begin rdoc
A contact stores the address, name, phone, etc from a person or company. Every user has its own contact node used to store a biography and/or a portrait (through the 'icon' link).

=== Version

The version class used by contacts is the ContactVersion.

=== Content

Content is managed by the ContactContent. This class is responsible for storing contact information. It provides the following attributes to the Contact :

c_first_name:: first name
c_name::       name
c_address::    address (text)
c_zip::        zip code
c_city::       city name
c_telephone::  phone number
c_mobile::     mobile phone number
c_email::      email address
c_birthday::   birthday (date)

=== links

Default links for Contact are:

contact_for::  unique contact reference for a project (can be the project's address, client, etc).
collaborator_for:: projects in which the contact is involved as a collaborator.
favorites::    used by users to tag some pages as their favorites thus displaying them in their 'favorites' menu.
=end
class Contact < Reference
  link :contact_for, :class_name=>'Project', :as=>'contact', :as_unique=>true
  link :collaborator_for, :class_name=>'Project', :as=>'collaborator'
  link :favorites,   :class_name=>'Node'
  
  private
  # TODO: test
  def version_class
    ContactVersion
  end
end
