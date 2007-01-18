class Project < Page
  has_many :nodes
  after_save :check_project_id
  link :news, :class_name=>'Note', :as=>'calendar', :collector=>true
  link :hot,  :class_name=>'Node', :unique=>true
  link :contact, :class_name=>'Contact', :unique=>true
  
  def before_destroy
    super
    if errors.empty?
      errors.add('base', "project not empty") unless self.nodes.count == 0
    end
  end
  
  # All notes from this project
  def notes(options={})
    options = {:order=>'log_at DESC'}.merge(options)
    Note.with_scope(:find=>{:conditions => ["nodes.project_id = ?", self[:id] ]}) do
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
