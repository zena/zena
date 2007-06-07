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
    super + ['notes_all', 'posts']
  end
  
  # This project's notes
  def notes(opts={})
    options = {:order=>'log_at DESC'}.merge(opts)
    secure(Note) { Note.find(:all, relation_options(options)) }
  end

  # TODO: test
  # The project's notes with the notes added to the project through 'project'
  def notes_all(opts={})
    options = {:order=>'log_at DESC', :or=>['project_id = ?', self[:id]]}.merge(opts)
    notes_added(options)
  end
  
  def posts(opts={})
    options = {:order=>'log_at DESC'}.merge(opts)
    secure(Note) { Post.find(:all, relation_options(options)) }
  end
    
  # All events related to this project (new/modified pages, notes)
  def timeline
    []
  end
end
