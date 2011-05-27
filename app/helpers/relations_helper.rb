module RelationsHelper
  def show_dir
    @show_dir || params[:dir]
  end
end
