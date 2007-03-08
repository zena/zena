module ZenaTestUnit
  include Zena::Acts::SecureScope
  include Zena::Acts::SecureController::InstanceMethods
  
  # redefine lang for tests (avoids using session[:lang]):
  def lang
    return @lang if @lang
    if ZENA_ENV[:monolingual]
      @lang = ZENA_ENV[:default_lang]
    else
      @lang ||= ZENA_ENV[:languages].include?(visitor.lang) ? visitor.lang : ZENA_ENV[:default_lang]
    end
  end
  
  def visitor
    return @visitor if @visitor
    visitor_id = (@controller && session.is_a?(ActionController::TestSession) && session[:user]) ? session[:user] : 1
    @visitor = User.find(visitor_id)
  end
  
  # Set visitor for unit testing
  def login(name=nil)
    if name
      @visitor = User.find_by_login(name.to_s)
      @lang = @visitor.lang
    else
      @visitor = User.find(1)
      @lang = ZENA_ENV[:default_lang]
    end
  end
  
  def err(obj)
    obj.errors.each do |er,msg|
      puts "[#{er}] #{msg}"
    end
  end
  
end
