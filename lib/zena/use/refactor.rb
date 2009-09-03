module Zena
  module Use
    module Refactor
      module Common

        # TODO: test
        def lang
          visitor.lang
        end
      end # Common
      
      module ControllerMethods
        include Common
        
        # TODO: test
        def visitor
          @visitor ||= returning(User.make_visitor(:host => request.host, :id => session[:user])) do |user|
            if session[:user] != user[:id]
              # changed user (login/logout)
              session[:user] = user[:id]
            end
            if user.is_anon?
              user.ip = request.headers['REMOTE_ADDR']
            end
          end
        end
        
        # Read the parameters and add errors to the object if it is considered spam. Save it otherwize.
        def save_if_not_spam(obj, params)
          # do nothing (overwritten by plugins like zena_captcha)
          obj.save
        end
        
      end # ControllerMethods
      
      module ViewMethods
        include Common
        
        # TODO: use Rails native helper.
        def javascript( string )
          javascript_start +
          string +
          javascript_end
        end

        def javascript_start
          "<script type=\"text/javascript\" charset=\"utf-8\">\n// <![CDATA[\n"
        end

        def javascript_end
          "\n// ]]>\n</script>"
        end
        
        # Quote for html values (input tag, alt attribute, etc)
        def fquote(text)
          text.to_s.gsub("'",'&apos;')
        end
        
        # TODO: see if this is still needed. Creates a pseudo random string to avoid browser side ajax caching
        def rnd
          Time.now.to_i
        end

        # We need to create the accessor for zafu calls to the helper to work when compiling templates. Do not ask me why this works...
        def session
          @session || {}
        end

        # We need to create the accessor for zafu calls to the helper to work when compiling templates. Do not ask me why this works...
        def flash
          @flash || {}
        end
        
        # TODO: refactor with new RedCloth
        def add_place_holder(str)
          @placeholders ||= {}
          key = "[:::#{self.object_id}.#{@placeholders.keys.size}:::]"
          @placeholders[key] = str
          key
        end

        # Replace placeholders by their real values
        def replace_placeholders(str)
          (@placeholders || {}).each do |k,v|
            str.gsub!(k,v)
          end
          str
        end
        
        # return a readable text version of a file size
        # TODO: use number_to_human_size instead
        def fsize(size)
          size = size.to_f
          if size >= 1024 * 1024 * 1024
            sprintf("%.2f Gb", size/(1024*1024*1024))
          elsif size >= 1024 * 1024
            sprintf("%.1f Mb", size/(1024*1024))
          elsif size >= 1024
            sprintf("%i Kb", (size/(1024)).ceil)
          else
            sprintf("%i octets", size)
          end
        end
        
        # TODO: is this still used ?
        def show(obj, sym, opt={})
          return show_title(obj, opt) if sym == :v_title
          if opt[:as]
            key = "#{opt[:as]}#{obj.zip}.#{obj.v_number}"
            preview_for = opt[:as]
            opt.delete(:as)
          else
            key = "#{sym}#{obj.zip}.#{obj.v_number}"
          end
          if opt[:text]
            text = opt[:text]
            opt.delete(:text)
          else
            text = obj.send(sym)
            if text.blank? && sym == :v_summary
              text = obj.v_text
              opt[:images] = false
            else
              opt.delete(:limit)
            end
          end
          if [:v_text, :v_summary].include?(sym)
            if obj.kind_of?(TextDocument) && sym == :v_text
              lang = obj.content_lang
              lang = lang ? " lang='#{lang}'" : ""
              text = "<code#{lang} class='full'>#{text}</code>"
            end
            text  = zazen(text, opt)
            klass = " class='zazen'"
          else
            klass = ""
          end
          if preview_for
            render_to_string :partial=>'nodes/show_attr', :locals=>{:id=>obj[:id], :text=>text, :preview_for=>preview_for, :key=>key, :klass=>klass,
                                                                 :key_on=>"#{key}#{Time.now.to_i}_on", :key_off=>"#{key}#{Time.now.to_i}_off"}
          else
            "<div id='#{key}'#{klass}>#{text}</div>"
          end
        end
      
        # TODO: remove ?
        def css_edit(css_file = 'zen.css')
          return '' if RAILS_ENV == 'production'
          str = <<ENDTXT
    <div id='css_edit'>
      <div id='css' onclick='cssUpdate()'></div>
      <script type="text/javascript">
      var c=0
      var t
      function timedCount()
      {
        var file = $('css_file').value
        if (c == '#'){
          c = '_'
        } else {
          c = '#'
        }
        document.getElementById('css_counter').innerHTML=c

        new Ajax.Request('/z/version/css_preview', {asynchronous:true, evalScripts:true, parameters:'css='+file});
        t=setTimeout("timedCount()",2000)
      }

      function stopCount()
      {
        clearTimeout(t)
      }

      </script>
      <form>
        <input type="button" value="Start CSS" onclick="timedCount()">
        <input type="button" value="Stop  CSS" onclick="stopCount()">
        <span id='css_counter'></span> <input type='text' id='css_file' name='css_file' value='#{css_file}'/>
      </form>
    </div>

ENDTXT
        end
        
        # Traductions as a list of links
        def traductions(opts={})
          obj = opts[:node] || @node
          trad_list = []
          (obj.traductions || []).each do |ed|
            trad_list << "<span#{ ed.lang == lang ? " class='current'" : ''}>" + link_to( _(ed[:lang]), zen_path(obj,:lang=>ed[:lang])) + "</span>"
          end
          trad_list
        end

        def change_lang(new_lang)
          if visitor.is_anon?
            {:overwrite_params => { :prefix => new_lang }}
          else
            {:overwrite_params => { :lang => new_lang }}
          end
        end
        
        # This lets helpers render partials
        # TODO: make sure this is the best way to handle this problem.
        def render_to_string(*args)
          @controller ||= begin
             # ==> this means render_to_string uses a view with everything ApplicationController has...
            ApplicationController.new.instance_eval do
              class << self
                attr_accessor :request, :response, :params
              end
            
              @request = ::ActionController::TestRequest.new
              @response = ::ActionController::TestResponse.new

              @params = {}
              send(:initialize_current_url)
              @template = @response.template = ::ActionView::Base.new(self.class.view_paths, {}, self)
              @template.helpers.send :include, self.class.master_helper_module
              self
            end
          end
          
          @controller.send(:render_to_string, *args)
        end

      end # ViewMethods      
    end # Refactor
  end # Use
end # Zena