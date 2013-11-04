require 'authlogic/test_case'
require 'hpricot'

module Zena
  module Use
    module TestHelper
      include Zena::Use::Upload::UploadedFile

      # Set visitor for unit testing
      def login(fixture, host = nil)
        user = users(fixture)
        if host
          site = Site.setup_master(Site.find_by_host(host))
        else
          # Not an alias
          site = user.site
        end
        setup_visitor(user, site)
        user.ip = '10.0.0.44'
        $_test_site = site.name
        ::I18n.locale = user.lang
      end

      # Show object's errors
      def err(obj)
        obj.errors.each_error do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end

      def set_date(node_syms, opts = {}, site = 'zena')
        $_test_site = site
        fld = opts.delete(:fld) || 'log_at'
        if opts == {}
          date = Time.now
        else
          date = Time.now.advance(opts)
        end
        ids = node_syms.kind_of?(Array) ? node_syms.map{|node_sym| nodes_id(node_sym) } : [nodes_id(node_syms)]
        Node.connection.execute "UPDATE nodes SET #{fld} = '#{date.strftime('%Y-%m-%d %H:%M')}' WHERE id IN (#{ids.join(',')})"
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
      def uploaded_fixture(fname, content_type="application/octet-stream", filename=nil)
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
        uploaded_file(t, filename, content_type)
      end

      # JPEG helper
      def uploaded_jpg(fname, filename=nil)
        uploaded_fixture(fname, 'image/jpeg', filename)
      end

      # Pdf helper
      def uploaded_pdf(fname, filename=nil)
        uploaded_fixture(fname, 'application/pdf', filename)
      end

      # TEXT helper
      def uploaded_text(fname, filename=nil)
        uploaded_fixture(fname, 'text/plain', filename)
      end

      # PNG helper
      def uploaded_png(fname, filename=nil)
        uploaded_fixture(fname, 'image/png', filename)
      end

      # TGZ helper
      def uploaded_archive(fname, filename=nil)
        uploaded_fixture(fname, 'application/x-gzip', filename)
      end

      # ZIP helper
      def uploaded_zip(fname, filename=nil)
        uploaded_fixture(fname, 'application/zip', filename)
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

      def execute_after_commit!
        Node.connection.instance_eval do
          # Simulate commit
          if actions = @after_commit
            @after_commit = nil
            actions.each do |block|
              block.call
            end
          end
        end
      end
    end
  end # Use
end # Zena