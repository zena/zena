class Contact < Reference

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

  safe_method :fullname => String, :initials => String
  safe_method :created_at => Time, :updated_at => Time, :fullname => String, :initials => String,
              :address => String

  attr_protected     :site_id

  class << self

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Contact')
    end
  end

  def fullname(first_name = self.first_name, name = self.name)
    (!first_name.blank? && !name.blank?) ? (first_name + ' ' + name) : (first_name.blank? ? name : first_name)
  end

  def fullname_changed?
    self.properties.first_name_changed? || self.properties.name_changed?
  end

  def fullname_was
    fullname(self.properties.first_name_was, self.properties.name_was)
  end

  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end

  private
    def set_defaults
      self.title ||= fullname

      if self.properties.title_was == fullname_was
        self.title = fullname
      end

      super
    end
end
