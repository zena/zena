=begin rdoc

Beware that the project is not in it's own project. The project's project_id is the same as it's parent. This should not confuse you too much as finding the root node for a project is not as interesting as finding the projects in a project.
=end
class Project < Page
  
  def get_project_id
    self[:id]
  end
end
