class Project < Page
  has_many :nodes
  after_save :check_project_id
  link :news, :class_name=>'Note', :as=>'calendar', :collector=>true
  link :hot,  :class_name=>'Node', :unique=>true
  link :contact, :class_name=>'Contact', :unique=>true
  link :notes_added, :class_name=>'Note', :as=>'project', :collector=>true
  
  def before_destroy
    super
    if errors.empty?
      errors.add('base', "project not empty") unless self.nodes.count == 0
    end
  end
  
  # This project's notes
  def notes(options={})
    options = {:order=>'log_at DESC'}.merge(options)
    Note.with_scope(:find=>{:conditions => ["project_id = ?", self[:id] ]}) do
      secure(Note) { Note.find(:all, options) }
    end
  end
  
  # TODO: test
  # The project's notes with the added_notes
  def all_notes(options={})
    options = {:order=>'log_at DESC', :or=>['project_id = ?', self[:id]]}.merge(options)
    notes_added(options)
  end
=begin
    conditions = options[:conditions]
    options.delete(:conditions)
    options.merge!( :select     => "#{Note.table_name}.*, links.id AS link_id, links.role", 
                    :joins      => "LEFT JOIN links ON #{Note.table_name}.id=links.source_id",
                    :conditions => ["(project_id = ?) OR (links.role='project' AND links.target_id = ? AND links.id IS NOT NULL)", self[:id], self[:id] ]
                    )
    if conditions
      Note.with_scope(:find=>{:conditions=>conditions}) do
        secure(Note) { Note.find(:all, options ) }
      end
    else   
      secure(Note) { Note.find(:all, options ) }
    end
  end
=end
  
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
