require 'differ'
class VersionsController < ApplicationController
  layout :popup_layout, :except => [:preview, :diff, :show]
  before_filter :find_version, :verify_access

  # Display a specific version of a node
  def show
    respond_to do |format|

      format.html {
        if @node.id == current_site.root_id
          render_and_cache :cache => false, :mode => '+index'
          insert_warning
        else
          render_and_cache :cache => false
          insert_warning
        end
      }

      format.xml  { render :xml => @node.to_xml }

      format.js # show.rjs

      format.all  do
        # Get document data (inline if possible)
        if params[:format] != @node.safe_content_read('ext')
          return redirect_to(params.merge(:format => (@node.safe_content_read('ext') || 'html')))
        end

        if @node.kind_of?(Image) && !Zena::Use::ImageBuilder.dummy?
          img_format = Iformat[params[:mode]]
          data = @node.file(img_format)
          content_path = @node.filepath(img_format)
          disposition  = 'inline'

        elsif @node.kind_of?(TextDocument)
          data = StringIO.new(@node.text)
          content_path = nil
          disposition  = 'attachment'

        else
          data         = @node.file
          content_path = @node.filepath
          disposition  = 'inline'
        end
        raise ActiveRecord::RecordNotFound unless data

        send_data( data.read , :filename => @node.filename, :type => @node.content_type, :disposition => disposition)
        data.close

        # should we cache the page ?
        # cache_page(:content_path => content_path) # content_path is used to cache by creating a symlink
      end
    end
  end

  def edit
    if params[:drive]
      if @node.redit
        flash[:notice] = _("Version changed back to redaction.")
      else
        flash[:error] = _("Could not change version back to redaction.")
      end
      render :action=>'update'
    else
      @title_for_layout = @node.rootpath
      if @node.kind_of?(TextDocument)
        if params['parse_assets']
          @node.text = @node.parse_assets(@node.text, self, 'text')
        elsif @node.kind_of?(TextDocument) && params['unparse_assets']
          @node.text = @node.unparse_assets(@node.text, self, 'text')
        end
      end
      @edit = true
    end
    if params[:close] == 'true'
      js_data << "Zena.reloadAndClose();"
    else
      js_data << <<-END_TXT
      Zena.editor_setup('#{preview_node_version_path(:node_id=>@node[:zip], :id=>(@node.version.number || 0), :escape => false)}');
      END_TXT
    end
  end

  def custom_tab
    render :file => template_url(:mode=>'+edit', :format=>'html'), :layout=>false
  rescue ActiveRecord::RecordNotFound
    @node.load_roles!
    render :action => 'custom_tab'
  end

  # TODO: test/improve or remove (experiments)
  def diff
    # source
    source = @node.version.prop

    # target
    if params[:to].to_i > 0
      version = secure!(Version) { Version.find(:first, :conditions => ['node_id = ? AND number = ?', @node.id, params[:to]])}
      @node.version = version
    else
      # default
      @node.instance_variable_set(:@version, nil)
    end
    target = @node.prop

    keys = (target.keys + source.keys).uniq

    keys.each do |k|
      target[k] = Differ.diff_by_word(
        target[k] || '',
        source[k] || '').format_as(:html).gsub(/(\s+)<\/del>/, '</del>\1')
    end

    show
  end

  # preview when editing node
  def preview
    if @key = (params['key'] || params['amp;key'])
      if @node.can_write?
        @value = params[:content]
        if @node.kind_of?(TextDocument) && @key == 'text'
          l = @node.content_lang
          @value = "<code#{l ? " lang='#{l}'" : ''} class=\'full\'>#{@value}</code>"
        end
      else
        @value = "<span style='background:#f66;padding:10px; border:1px solid red; color:black;font-size:10pt;font-weight:normal;'>#{_('you do not have write access here')}#{visitor.is_anon? ? " (<a style='color:#00a;text-decoration:underline;' href='/login'>#{_('please login')}</a>)" : ""}</span>"
      end
    else
      # elsif @node.kind_of?(Image)
      #   # view image version
      #   # TODO: how to show the image data of a version ? 'nodes/3/versions/4.jpg' ?
      #   @node.text = "<img src='#{url_for(:controller=>'versions', :node_id=>@node[:zip], :id=>@node.v_number, :format=>@node.ext)}'/>"
      # elsif @node.kind_of?(TextDocument)
      #   lang = @node.content_lang
      #   lang = lang ? " lang='#{lang}'" : ""
      #   @node.text = "<code#{lang} class='full'>#{@text}</code>"
    end


    respond_to do |format|
      format.js
    end
  end

  # This is a helpers used when creating the css for the site. They have no link with the database
  def css_preview
    file = params[:css].gsub('..','')
    path = File.join(Zena::ROOT, 'public', 'stylesheets', file)
    if File.exists?(path)
      if session[:css] && session[:css] == File.stat(path).mtime
        render :nothing=>true
      else
        session[:css] = File.stat(path).mtime
        @css = File.read(path)
      end
    else
      render :nothing=>true
    end
  end

  def propose
    if @node.propose
      flash[:notice] = _("Redaction proposed for publication.")
    else
      flash[:error] = _("Could not propose redaction.")
    end
    do_rendering
  end

  def refuse
    if @node.refuse
      flash[:notice] = _("Proposition refused.")
      @redirect_url = @node.can_read? ? request.env['HTTP_REFERER'] : user_path(visitor)
    else
      flash[:notice] = _("Could not refuse proposition.")
    end
    do_rendering
  end

  def publish
    if @node.publish
      flash[:notice] = "Redaction published."
    else
      flash[:error] = "Could not publish: #{error_messages_for(:node, :object => @node)}"
    end
    do_rendering
  end

  def remove
    if @node.remove
      flash[:notice] = "Publication removed."
    else
      flash[:error] = "Could not remove plublication."
    end
    do_rendering
  end

  def redit
    if @node.redit
      flash[:notice] = "Rolled back to redaction."
    else
      flash[:error] = "Could not rollback: #{error_messages_for(:node, :object => @node)}"
    end
    do_rendering
  end

  # TODO: test
  def unpublish
    if @node.unpublish
      flash[:notice] = "Publication removed."
    else
      flash[:error] = "Could not remove publication."
    end
    do_rendering
  end

  # TODO: test
  def destroy
    if @node.destroy_version
      if @node.versions.empty?
        flash[:notice] = "Node destroyed."
        respond_to do |format|
          format.html { redirect_to zen_path(@node.parent) }
          format.js
        end
      else
        flash[:notice] = "Version destroyed."
        do_rendering
      end
    else
      flash[:error] = "Could not destroy version."
      do_rendering
    end
  end


  protected
    def find_version
      @node = secure!(Node) { Node.find_by_zip(params[:node_id]) }
      if params[:id].to_i != 0
        unless version = Version.find(:first, :conditions => ['node_id = ? AND number = ?', @node.id, params[:id]])
          redirect_to :id => @node.version.number
        else
          @node.version = version
        end
      end
    end

    def verify_access
      raise ActiveRecord::RecordNotFound unless @node.can_write?
    end

    def do_rendering
      # make the flash available to rjs helpers
      @flash = flash
      respond_to do |format|
        format.html { redirect_to @redirect_url || request.env['HTTP_REFERER'] || {:id => 0}}
        # js = call from 'drive' popup
        format.js   { render :action => 'update' }
      end
    end

    def insert_warning
      response.body.gsub!('</html>', %Q{<div id='version_warning' class='s#{@node.version.status}'><a href='#{zen_path(@node)}'>#{_('close')}</a> version: <b>#{@node.version.number}</b><br/>author: <b>#{@node.version.user.login}</b><br/>date: #{format_date(@node.version.created_at, _('full_date'))}</div></html>})
    end
end