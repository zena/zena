module ZenaTestUnit
  include Zena::Acts::SecureScope
  include Zena::Acts::SecureController::InstanceMethods
  
  # redefine lang for tests (avoids using params[:lang]):
  def lang
    @lang ||= (@controller && session.is_a?(ActionController::TestSession)) ? (session[:lang] || (session[:user] ? session[:user][:lang] : ZENA_ENV[:default_lang])) : ZENA_ENV[:default_lang]
  end
  def visitor_id
    @visitor_id ||= (@controller && session.is_a?(ActionController::TestSession) && session[:user]) ? session[:user][:id] : 1
  end

  def visitor_groups
    @visitor_groups ||= (@controller && session.is_a?(ActionController::TestSession) && session[:user]) ? session[:user][:groups] : [1]
  end
  # 
  # Set visitor for unit testing
  def visitor(name=nil)
    if name
      user = User.find_by_login(name.to_s)
      @visitor_id = user.id
      @visitor_groups = user.group_ids
      @lang = user.lang
    else
      @visitor_id = 1
      @visitor_groups = [1]
      @lang = 'en'
    end
  end
  
  def set_lang(l)
    @lang = l
  end
  
  def err(obj)
    obj.errors.each do |er,msg|
      puts "[#{er}] #{msg}"
    end
  end
  
end
