module ZenaTestController
  
  def init_controller
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.instance_eval { @session = {}; @params = {}; @url = ActionController::UrlRewriter.new( @request, {} )}
  end

  def login(visitor=:ant)
    @controller_bak = @controller
    @controller = LoginController.new
    post 'login', :user=>{:login=>visitor.to_s, :password=>visitor.to_s}
    sess = @controller.instance_eval { @session }
    @controller_bak.instance_eval { @session = sess }
    @controller = @controller_bak
  end
  
  def logout
    @controller_bak = @controller
    @controller = LoginController.new
    post 'logout'
    sess = @controller.instance_eval { @session }
    @controller_bak.instance_eval { @session = sess }
    @controller = @controller_bak
  end
  
  def session
    @controller.instance_eval { @session }
  end
  
  def method_missing(meth,*args, &block)
    @controller.send(meth, *args, &block)
  end
end
