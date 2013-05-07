require 'uri'
require 'net/http'
require 'uuidtools'

module Zena
  module Use
    module Upload
      UPLOAD_KEY = defined?(Mongrel) ? 'upload_id' : "X-Progress-ID"
      
      def self.has_network?
        response = nil
        Net::HTTP.new('example.com', '80').start do |http|
          response = http.head('/')
        end
        response.kind_of? Net::HTTPSuccess
      rescue
        false
      end

      module UploadedFile
        protected
          def uploaded_file(file, filename = nil, content_type = nil)
            (class << file; self; end;).class_eval do
              alias local_path path if respond_to?(:path)  # FIXME: do we need this ?
              define_method(:original_filename) { filename }
              define_method(:content_type) { content_type }
            end
            file
          end
      end # UploadedFile

      module ControllerMethods
        include UploadedFile
        protected
          include ActionView::Helpers::NumberHelper # number_to_human_size
          def get_attachment
            att, error = nil, nil
            if !params['attachment_url'].blank?
              att, error = fetch_uri(params['attachment_url'])
            else
              att = params['attachment']
            end
            yield(att, error) if block_given?
            [att, error]
          end
          

        private
          def fetch_uri(uri_str, max_file_size = 10)
            max_file_size = max_file_size * 1024 * 1024 # Mo

            # first check head
            response, error = fetch_response(uri_str, :head)
            return [nil, error] unless response
            if response['Content-Length'].nil?
              return [nil, 'unknown size: cannot fetch url']
            elsif response['Content-Length'].to_i > max_file_size
              return [nil, 'size (%s) too big to fetch url' % number_to_human_size(response['Content-Length'].to_i)]
            end

            # Size is ok, get content
            response, error = fetch_response(uri_str, :body)
            return [nil, error] unless response

            tmpf = Tempfile.new('fetch_uri')
            File.open(tmpf.path, 'wb') do |file|
              file.write(response.body)
            end
            if content_disposition = response['Content-Disposition']
              original_filename = content_disposition[/filename\s*=\s*('|")(.+)\1/,2]
            else
              original_filename = uri_str.split('/').last
            end

            [uploaded_file(tmpf, original_filename, response['Content-Type'])]
          end

          def fetch_response(uri_str, type = :body, limit = 10)
            return [nil, 'too many redirects'] if limit == 0
            response = nil
            uri = URI.parse(URI.escape(uri_str))
            return [nil, 'invalid url'] unless uri.kind_of?(URI::HTTP)
            Net::HTTP.new(uri.host, uri.port).start do |http|
              if type == :body
                response = http.request_get(uri.request_uri)
              else
                response = http.head(uri.request_uri)
              end
            end

            case response
            when Net::HTTPSuccess
              response
            when Net::HTTPRedirection
              redirect = response['location']
              port = (uri.scheme == 'http' && uri.port == 80) ? '' : ":#{uri.port}"
              redirect = "#{uri.scheme}://#{uri.host}#{port}/#{redirect}" unless redirect =~ /\A\w+:\/\//
              fetch_response(redirect, type, limit - 1)
            else
              [nil, 'not found']
            end
          rescue URI::InvalidURIError
            [nil, 'invalid url']
          end

          def render_get_uf
            @uuid = params[:uuid]
            render :inline => "<%= link_to_function(_('cancel'), \"['file', 'upload_field'].each(Element.toggle);$('upload_field').innerHTML = '';\")%><%= upload_field %>"
          end

          def render_upload_progress
            # When using the mod_upload_progress module, this is never hit:
            # <Location /upload_progress>
            #   ReportUploads On
            # </Location>
            #
            # When using Mongrel: mimic apache2 mod_upload_progress
            #
            # if (!found) {
            #   response = apr_psprintf(r->pool, "new Object({ 'state' : 'starting' })");
            # } else if (err_status >= HTTP_BAD_REQUEST  ) {
            #   response = apr_psprintf(r->pool, "new Object({ 'state' : 'error', 'status' : %d })", err_status);
            # } else if (done) {
            #   response = apr_psprintf(r->pool, "new Object({ 'state' : 'done' })");
            # } else if ( length == 0 && received == 0 ) {
            #   response = apr_psprintf(r->pool, "new Object({ 'state' : 'starting' })");
            # } else {
            #   response = apr_psprintf(r->pool, "new Object({ 'state' : 'uploading', 'received' : %d, 'size' : %d, 'speed' : %d  })", received, length, speed);
            # }
            render :update do |page|
              begin
                @status = Mongrel::Uploads.check(params[:"X-Progress-ID"])
                if @status
                  if @status[:received] != @status[:size]
                    page << "new Object({ 'state' : 'uploading', 'received' : #{@status[:received]}, 'size' : #{@status[:size]} })"
                  else
                    page << "new Object({ 'state' : 'done' })"
                  end
                else
                  #page << "new Object({ 'state' : 'done' })"
                end
              rescue NameError
                page << "new Object({ 'state' : 'upload in progress..' })"
              end
            end
          end
          
          def render_upload
            responds_to_parent do # execute the redirect in the iframe's parent window
              render :update do |page|
                if @node.new_record?
                  page << "UploadProgress.setAsError(#{error_messages_for(:node, :object => @node).inspect})"
                  Node.logger.warn "ERROR #{error_messages_for(:node, :object => @node)}"
                  page.replace_html 'form_errors', error_messages_for(:node, :object => @node)
                else
                  page.call 'UploadProgress.setAsFinished'
                  page.delay(1) do # allow the progress bar fade to complete
                    if js = params[:js]
                      page << js.gsub('NODE_ID', @node.zip.to_s)
                    end
                    if params[:reload]
                      page << "Zena.t().Zena.reload(#{params[:reload].inspect})"
                    end
                    if params[:redir] == 'more'
                      # This is used when we want "upload more" in popup window.
                      page.redirect_to document_url(@node[:zip], :reload => params[:reload], :js => params[:js])
                    elsif params[:redir]
                      page << "Zena.t().window.location = #{params[:redir].gsub('NODE_ID', @node.zip.to_s).inspect}"
                    end
                  end
                end
              end
            end
          end
      end # ControllerMethods

      module ViewMethods
        include RubyLess

        def upload_form_tag(url_opts, html_opts = {})
          @uuid = UUIDTools::UUID.random_create.to_s.gsub('-','')
          html_opts.reverse_merge!(:multipart => true, :id => "UploadForm#{@uuid}")
          if html_opts[:multipart]
            html_opts[:onsubmit] = "submitUploadForm('#{html_opts[:id]}', '#{@uuid}');"
            url_opts[UPLOAD_KEY] = @uuid
          end
          if block_given?
            form_tag( url_opts, html_opts ) do |f|
              yield(f)
            end
          else
            form_tag( url_opts, html_opts )
          end
        end

        def upload_field(opts = {})
          uuid = opts[:uuid] || @uuid
          dom  = opts[:dom]  || 'node'
          case opts[:type].to_s
          when 'onclick'
            link = link_to_remote(_("change"), :update=>'upload_field', :url => get_uf_documents_path(:uuid => @uuid), :method => :get, :complete=>"['file', 'upload_field'].each(Element.toggle);")
            <<-TXT
<label for='attachment'>#{_('file')}</label>
<div id="file" class='toggle_div'>#{link}</div>
<div id="upload_field" class='toggle_div' style='display:none;'></div>
TXT
          else
            attach_file_id, attach_url_id = "af#{uuid}", "au#{uuid}"
            onchange = %Q{onchange="Zena.get_filename(this,'#{dom}_title'); $('#{dom}_title').focus(); $('#{dom}_title').select();"}
            <<-TXT
<div id='#{attach_file_id}' class='attach'><label for='attachment' onclick=\"['#{attach_file_id}', '#{attach_url_id}'].each(Element.toggle);\">#{_('file')} / <span class='off'>#{_('url')}</span></label>
<input  style='line-height:1.5em;' id="attachment#{uuid}" name="attachment" #{onchange} class='file' type='file'/></div>

<div id='#{attach_url_id}' class='attach' style='display:none;'><label for='url' onclick=\"['#{attach_file_id}', '#{attach_url_id}'].each(Element.toggle);\"><span class='off'>#{_('file')}</span> / #{_('url')}</label>
<input  style='line-height:1.5em;' size='30' id='attachment_url' type='text' #{onchange} name='attachment_url'/><br/></div>
TXT
          end
        end
      end # ViewMethods
    end # Upload
  end # Use
end # Zena