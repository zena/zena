module UsersHelper

  def contact_form
    node_back = @node # store contextual node
    begin
      @node = @user.contact || current_site.usr_prototype
      begin
        res =render :file => template_url(:mode => '+user', :format => 'html')
      rescue ActiveRecord::RecordNotFound
        @node.load_roles!
        res = render :file => 'versions/custom_tab'
      end
    ensure
      @node = node_back
    end
    res
  end
end