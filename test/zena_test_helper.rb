module HelperTestSetup
  def setup(request, response, url)
    @request = request
    @url = url
    initialize_template_class(response)
    assign_shortcuts(request, response)
    initialize_current_url
    assign_names
  end
  def rescue_action(e) raise e end;
end

module ZenaTestHelper
  attr_accessor :flash, :controller
  
  include ActionView::Helpers::ActiveRecordHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::PrototypeHelper
  
  def setup
    @controllerClass ||= ApplicationController
    self.class.send(:include,@controllerClass.master_helper_module)
    eval "class StubController < #{@controllerClass}; include HelperTestSetup; end"
    super

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = StubController.new
    # Fake url rewriter so we can test url_for
    @url     = ActionController::UrlRewriter.new @request, {}
    @controller.setup(@request, @response, @url)
    @flash = {}
    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end
  
  # login for functional testing
  def login(visitor=:ant)
    @controller_bak = @controller
    @controller = LoginController.new
    post 'login', :user=>{:login=>visitor.to_s, :password=>visitor.to_s}
    @controller = @controller_bak
  end
  
  def logout
    @controller_bak = @controller
    @controller = LoginController.new
    post 'logout'
    @controller = @controller_bak
  end
  
  def secure(*args, &block)
    @controller.send(:secure, *args, &block)
  end
  
  def err(obj)
    obj.errors.each do |er,msg|
      puts "[#{er}] #{msg}"
    end
  end
end
