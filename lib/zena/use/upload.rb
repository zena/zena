require 'uri'
require 'net/http'
require 'uuidtools'

module Zena
  module Use
    module Upload
      module ControllerMethods
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
            (class << tmpf; self; end;).class_eval do
              alias local_path path if defined?(:path)
              define_method(:original_filename) { original_filename }
              define_method(:content_type) { response['Content-Type'] }
            end
            return [tmpf]
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
              fetch_response(response['location'], type, limit - 1)
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
      end # ControllerMethods

      module ViewMethods
        UPLOAD_KEY = defined?(Mongrel) ? 'upload_id' : "X-Progress-ID"
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
          case opts[:type]
          when :onclick
            link = link_to_remote(_("change"), :update=>'upload_field', :url => get_uf_documents_path(:uuid => @uuid), :method => :get, :complete=>"['file', 'upload_field'].each(Element.toggle);")
            <<-TXT
<label for='attachment'>#{_('file')}</label>
<div id="file" class='toggle_div'>#{link}</div>
<div id="upload_field" class='toggle_div' style='display:none;'></div>
TXT
          else
            onchange = %Q{onchange="Zena.get_filename(this,'node_v_title'); $('node_v_title').focus(); $('node_v_title').select();"}
            <<-TXT
<label for='attachment'>#{_('file')}</label>
<input id="attachment#{@uuid}" name="attachment" #{onchange} class='file' type="file" />

<label for='url'>#{_('url')}</label>
<input id='attachment_url' type='text' #{onchange} name='attachment_url'/><br/>
TXT
          end
        end
      end # ViewMethods
    end # Upload
  end # Use
end # Zena