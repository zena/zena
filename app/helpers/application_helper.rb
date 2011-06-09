module ApplicationHelper
  def help(key)
    %Q{<div class='help'><p>#{_(key)}</p></div>}
  end
end

Bricks.apply_patches