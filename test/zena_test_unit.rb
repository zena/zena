module ZenaTestUnit
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
      user = User.find_by_login(name.to_s)
      @user_id = user.id
      @user_groups = user.group_ids
      @lang = user.lang
    else
      @user_id = 1
      @user_groups = [1]
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
  
  # taken from http://manuals.rubyonrails.com/read/chapter/28#page237 with some modifications
  def uploaded_file(fname, content_type="application/octet-stream", filename=nil)
    path = File.join(FILE_FIXTURES_PATH, fname)
    filename ||= File.basename(path)
    t = Tempfile.new(fname)
    FileUtils.copy_file(path, t.path)
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end

  # a JPEG helper
  def uploaded_jpeg(fname, filename=nil)
    uploaded_file(fname, 'image/jpeg', filename)
  end

  # a PDF helper
  def uploaded_pdf(fname, filename=nil)
    uploaded_file(fname, 'application/pdf', filename)
  end
end
