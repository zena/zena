class Zena::Contact < Reference
  safe_method :fullname => String, :initials => String

  # Minimal contact's properties.
  include Property
  property do |t|
    t.string   "first_name"
    t.string   "name"
    t.text     "address"
    t.string   "zip"
    t.string   "city"
    t.string   "telephone"
    t.string   "mobile"
    t.string   "email"
    t.date     "birthday"
    t.integer  "site_id"
    t.string   "country"
  end

  class << self

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Contact')
    end
  end

  def filter_attributes(new_attributes)
    attributes = super
    if self[:name].blank? && attributes['name'].blank? && (attributes['c_name'] || attributes['c_first_name'])
      attributes.merge('name'    => (attributes['c_first_name'].to_s + ' ' + attributes['c_name'].to_s))
    else
      attributes
    end
  end

  def fullname(first_name = self.first_name, name = self.name)
    (!first_name.blank? && !name.blank?) ? (first_name + " " + name) : (first_name.blank? ? name : first_name)
  end

  def fullname_changed?
    self.properties.first_name_changed? || self.properties.name_changed?
  end

  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
end
