module ZenaTestController
  
  def init_controller
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.instance_eval { @params = {}; @url = ActionController::UrlRewriter.new( @request, {} )}
    @controller.instance_variable_set(:@response, @response)
    @controller.instance_variable_set(:@session, @request.session)
  end

  def login(visitor=:anon)
    @controller_bak = @controller
    @controller = LoginController.new
    post 'login', :user=>{:login=>visitor.to_s, :password=>visitor.to_s}
    sess = @controller.instance_variable_get(:@session)
    if visitor == :anon
      sess[:user] = 1
    end
    @controller_bak.instance_variable_set(:@session, sess )
    @controller_bak.instance_variable_set(:@visitor, nil ) # clear cached visitor
    @controller = @controller_bak
  end
  
  def logout
    @controller_bak = @controller
    @controller = LoginController.new
    post 'logout'
    @controller_bak.instance_variable_set(:@session, @controller.instance_variable_get(:@session) )
    @controller = @controller_bak
  end
  
  def session
    @controller.instance_eval { @session }
  end
  
  def err(obj)
    obj.errors.each do |er,msg|
      puts "[#{er}] #{msg}"
    end
  end
  
  def method_missing(meth,*args, &block)
    @controller.send(meth, *args, &block)
  end
end
