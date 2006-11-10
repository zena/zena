class UnitTestCase < Test::Unit::TestCase
  #include ZenaGlobals
  include Zena::Acts::SecureScope
  include Zena::Acts::SecureController::InstanceMethods

  # redefine lang for tests (avoids using params[:lang]):
  def lang
    @lang ||= (@controller && session.is_a?(ActionController::TestSession)) ? (session[:lang] || (session[:user] ? session[:user][:lang] : ZENA_ENV[:default_lang])) : ZENA_ENV[:default_lang]
  end
  def user_id
    @user_id ||= (@controller && session.is_a?(ActionController::TestSession) && session[:user]) ? session[:user][:id] : 1
  end

  def user_groups
    @user_groups ||= (@controller && session.is_a?(ActionController::TestSession) && session[:user]) ? session[:user][:groups] : [1]
  end
  # 
  # Set visitor for unit testing
  def visitor(name=nil)
    if name
      user = addresses(name)
      @user_id = user.id
      @user_groups = user.group_ids
      @lang = user.lang
    else
      @user_id = 1
      @user_groups = [1]
      @lang = 'en'
    end
  end
  
  def err(obj)
    obj.errors.each do |er,msg|
      puts "[#{er}] #{msg}"
    end
  end
  
  def test_dummy
  end
    
end
