class BaseContact < Reference

  property do |t|
    t.string 'first_name', :index => true
    t.string 'name',       :index => true

    t.text   'address'
    t.string 'postal_code'
    t.string 'city'
    t.string 'country'

    t.string 'telephone'
    t.string 'mobile'
    t.string 'email'

    t.date   'birthday'
  end

  safe_property :first_name, :name,
                :address, :postal_code, :city, :country,
                :telephone, :mobile, :email,
                :birthday

  safe_method :fullname => String, :initials => String

  attr_protected :site_id

  class << self

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'BaseContact')
    end

    def ksel
      self == BaseContact ? 'C' : super
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

      if title.blank?
        self.title = fullname
      elsif fullname.blank?
        if title =~ /^(\S+)\s+(.*)$/
          self.first_name = $1
          self.name       = $2
        else
          self.name = title
        end
      end

      if properties.title_changed? && fullname_changed?
        # Ignore if both title and fullname changed
      elsif fullname_changed? && title == fullname_was
        # Fullname changed and title was in sync
        self.title = fullname
      end

      super
    end
end
