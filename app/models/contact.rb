class Contact < Page
  class << self
    def y_fields
      ["first_name","name","address","zip","city","telephone","mobile","email","birthday"]
    end
  end
end
