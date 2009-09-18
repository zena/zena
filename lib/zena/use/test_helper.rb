module Zena
  module Use
    module TestHelper
      # Set the current site used for testing (mostly to generate ids)
      def test_site(site_name)
        $_test_site = site_name
      end

      # Set visitor for unit testing
      def login(name='anon', site_name = nil)
        if site_name
          $_test_site = site_name
          @visitor = User.make_visitor(:user => name.to_s, :pass => name.to_s, :host => sites_host(site_name))
        else
          # find first matching site
          site = Site.find(:first, :select=>"sites.*, sites.name = '#{site_name}' AS site_ok", :from => "sites, participations",
                         :conditions=>["participations.site_id = sites.id AND participations.user_id = ?", users_id(name)], :order => "site_ok DESC")
          $_test_site  = site.name if site
          @visitor = User.make_visitor(:site => site, :id => users_id(name))
        end

        @visitor.ip = '10.0.0.127'
        ::I18n.locale = @visitor.lang
      end

      def preserving_files(path, &block)
        path = "/#{path}" unless path[0..0] == '/'
        if File.exist?("#{SITES_ROOT}#{path}")
          FileUtils::cp_r("#{SITES_ROOT}#{path}","#{SITES_ROOT}#{path}.bak")
          move_back = true
        else
          move_back = false
        end
        begin
          yield
        ensure
          FileUtils::rmtree("#{SITES_ROOT}#{path}")
          if move_back
            FileUtils::mv("#{SITES_ROOT}#{path}.bak","#{SITES_ROOT}#{path}")
          end
        end
      end

      def without_files(path, &block)
        path = "/#{path}" unless path[0..0] == '/'
        if File.exist?("#{SITES_ROOT}#{path}")
          FileUtils::mv("#{SITES_ROOT}#{path}","#{SITES_ROOT}#{path}.bak")
          move_back = true
        else
          move_back = false
        end
        begin
          yield
        ensure
          FileUtils::rmtree("#{SITES_ROOT}#{path}")
          if move_back
            FileUtils::mv("#{SITES_ROOT}#{path}.bak","#{SITES_ROOT}#{path}")
          end
        end
      end

      def with_caching
        @perform_caching_bak = ApplicationController.perform_caching
        ApplicationController.perform_caching = true
        Cache.perform_caching      = true
        CachedPage.perform_caching = true
        yield
      ensure
        Cache.perform_caching = @perform_caching_bak
        CachedPage.perform_caching = @perform_caching_bak
        ApplicationController.perform_caching = @perform_caching_bak
      end

      # taken from http://manuals.rubyonrails.com/read/chapter/28#page237 with some modifications
      def uploaded_file(fname, content_type="application/octet-stream", filename=nil)
        path = File.join(FILE_FIXTURES_PATH, fname)
        filename ||= File.basename(path)
        # simulate small files with StringIO
        if File.stat(path).size < 1024
          # smaller then 1 Ko
          t = StringIO.new(File.read(path))
        else
          t = Tempfile.new(fname)
          FileUtils.copy_file(path, t.path)
        end
        (class << t; self; end;).class_eval do
          alias local_path path if defined?(:path)
          define_method(:original_filename) { filename }
          define_method(:content_type) { content_type }
        end
        return t
      end

      # JPEG helper
      def uploaded_jpg(fname, filename=nil)
        uploaded_file(fname, 'image/jpeg', filename)
      end

      # PDF helper
      def uploaded_pdf(fname, filename=nil)
        uploaded_file(fname, 'application/pdf', filename)
      end

      # TEXT helper
      def uploaded_text(fname, filename=nil)
        uploaded_file(fname, 'text/plain', filename)
      end

      # PNG helper
      def uploaded_png(fname, filename=nil)
        uploaded_file(fname, 'image/png', filename)
      end

      # TGZ helper
      def uploaded_archive(fname, filename=nil)
        uploaded_file(fname, 'application/x-gzip', filename)
      end

      # ZIP helper
      def uploaded_zip(fname, filename=nil)
        uploaded_file(fname, 'application/zip', filename)
      end

      def file_path(filename, mode = 'full', content_id = nil)
        if content_id
          fname = filename.split('.').first
        else
          if content_id = document_contents_id(filename.to_sym)
            fname = filename.to_s.split('_').first
          else
            puts "#{filename.inspect} fixture not found in document_contents"
            return nil
          end
        end
        digest = Digest::SHA1.hexdigest(content_id.to_s)
        "#{SITES_ROOT}/test.host/data/#{mode}/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"
      end
    end
  end # Use
end # Zena