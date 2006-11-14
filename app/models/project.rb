class Project < Page
  has_and_belongs_to_many :participants, :join_table=>"contacts_projects",
                          :class_name=>"Contact"
  has_many :items
  after_save :check_project_id
  
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
  
  private
  def check_project_id
    Project.connection.execute("UPDATE #{self.class.table_name} SET project_id=id WHERE id=#{self[:id]}") unless self[:id] == self[:project_id]
    self[:project_id] = self[:id]
  end
end
