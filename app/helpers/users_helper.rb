module UsersHelper

  def node_form
    node_back = @node # store contextual node
    begin
      @node = @user.node || visitor.prototype
      begin
        res = render :file => template_url(:mode => '+user', :format => 'html')
      rescue ActiveRecord::RecordNotFound
        res = render :file => 'versions/custom_tab'
      end
    ensure
      @node = node_back
    end
    res
  end
end