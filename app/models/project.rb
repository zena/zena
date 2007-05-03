=begin rdoc

Beware that the project is not in it's own project. The project's project_id is the same as it's parent. This should not confuse you too much as finding the root node for a project is not as interesting as finding the projects in a project.
=end
class Project < Page
  link :news, :class_name=>'Note', :as=>'calendar', :collector=>true
  link :hot,  :class_name=>'Node', :unique=>true
  link :home, :class_name=>'Node', :unique=>true
  link :contact, :class_name=>'Contact', :unique=>true
  link :collaborators, :class_name=>'Contact'
  link :notes_added, :class_name=>'Note', :as=>'project', :collector=>true
  
  
  def get_project_id
    self[:id]
  end
  
  def relation_methods
    super + ['notes_all']
  end
  
  # This project's notes
  def notes(opts={})
    options = {:order=>'log_at DESC'}.merge(opts)
    secure(Note) { Note.find(:all, relation_options(options)) }
  end

  # TODO: test
  # The project's notes with the added_notes
  def notes_all(opts={})
    options = {:order=>'log_at DESC', :or=>['project_id = ?', self[:id]]}.merge(opts)
    notes_added(options)
  end
=begin
    conditions = options[:conditions]
    options.delete(:conditions)
    options.merge!( :select     => "#{Note.table_name}.*, links.id AS link_id, links.role", 
                    :joins      => "LEFT JOIN links ON #{Note.table_name}.id=links.source_id",
                    :conditions => ["(section_id = ?) OR (links.role='project' AND links.target_id = ? AND links.id IS NOT NULL)", self[:id], self[:id] ]
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
end
