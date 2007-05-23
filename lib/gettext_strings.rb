# gettext custom strings (dynamically constructed. please add a comment for the context where the string is used)
require 'gettext'
module Zena
  def CustomGettext
    N_('help_tab')  # edit form tab name
    
    N_('drive_tab') # drive form tab name
    N_('links_tab') # drive form tab name
    
    N_('text_tab')  # edit form tab name
    N_('title_tab') # edit form tab name
    N_('textdocument_tab')  # edit form tab
    N_('image_tab')         # edit form tab
    N_('document_tab')      # edit form tab
    N_('contact_tab')       # edit form tab
    
    N_('file_tab')              # document form tab name
    N_('template_tab')          # document form tab name
    N_('text_doc_tab')          # document form tab name
    
    N_('btn_add_doc') # used by zafu layout template
    
    N_('img_hot')           # link icon
    N_('img_calendar')      # link icon
    N_('img_contact')       # link icon
    N_('img_home')          # link icon
    N_('img_icon')          # link icon
    N_('img_tag')           # link icon
    N_('img_user')          # user management
    N_('img_collaborator')  # link icon
    N_('img_favorite')      # link icon
    N_('img_project')       # link icon
    N_('img_public')        # link icon
    N_('img_private')       # link icon
    N_('img_custom_inherit') # inherit icon
    
    N_('icon')
    N_('icon_for')
    N_('tags')
    N_('tag_for')
    N_('collaborators')
    N_('collaborator_for')
    N_('favorites')
    N_('favorite_for')
    N_('projects')
    N_('project_for')
    N_('calendars')
    N_('calendar_for')
    
    N_('posted by')
    N_('original by')
    N_('modified by')
    
    N_('img_user_admin')    # edit users (admin)
    N_('img_user_su')       # edit users (admin)
    N_('img_user_pub')      # edit users (admin)
    N_('img_group')         # edit groups (admin)
    N_('img_group_pub')     # edit users (admin)
    N_('img_group_admin')   # edit users (admin)
    N_('img_group_site')    # edit users (admin)
    
    N_('admin')             # user status
    N_('user')              # user status
    N_('commentator')       # user status
    N_('moderated')         # user status
    N_('reader')            # user status
    N_('deleted')           # user status
    
    N_('%{ext} document')   # alt attribute for img_tag 
    N_('%{type} node')      # alt attribute for img_tag
    
    N_('no result found')   # search template
    N_('search results')    # search template
    
    N_('btn_unplublish')    # version action
    
    N_('status_50')         # published
    N_('status_40')         # proposed
    N_('status_35')         # proposed with
    N_('status_33')         # redaction visible
    N_('status_30')         # redaction
    N_('status_20')         # replaced
    N_('status_10')         # removed
    N_('status_0')          # deleted
    
    N_('en')
    N_('fr')
    N_('de')
    N_('Monday')
    N_('Tuesday')
    N_('Wednesday')
    N_('Thursday')
    N_('Friday')
    N_('Saturday')
    N_('Sunday')
    
    N_('mon')
    N_('tue')
    N_('wed')
    N_('thu')
    N_('fri')
    N_('sat')
    N_('sun')
    
    N_('January')
    N_('February')
    N_('March')
    N_('April')
    N_('May')
    N_('June')
    N_('July')
    N_('August')
    N_('September')
    N_('October')
    N_('November')
    N_('December')
    
    N_('User name:')  # login form
    N_('Password:')   # login form
    
    # temporary (seems like the updatepo script does not parse 'templates' directory)
    N_('you are editing the original')
    N_('redaction saved')
  end
end