class Project < Page
  has_many :items
  after_save :check_project_id
  link :news, :class_name=>'Note', :as=>'calendar', :collector=>true
  link :hot,  :class_name=>'Item', :unique=>true
  link :address, :class_name=>'Contact', :unique=>true
  
  def before_destroy
    super
    if errors.empty?
      errors.add('base', "project not empty") unless self.items.count == 0
    end
  end
  
  # All notes from this project
  def notes(options={})
    options = {:order=>'log_at DESC'}.merge(options)
    Note.with_scope(:find=>{:conditions => ["items.project_id = ?", self[:id] ]}) do
      secure(Note) { Note.find(:all, options) }
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
