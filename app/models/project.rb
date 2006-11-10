class Project < Page
  has_and_belongs_to_many :participants, :join_table=>"contacts_projects",
                          :class_name=>"Contact"
  has_many :items
  
  def before_destroy
    super
    if errors.empty?
      errors.add('base', "project not empty") unless self.items.count == 0
    end
  end
  
  # All events related to this project (new/modified pages, notes)
  def timeline
    []
  end
end
