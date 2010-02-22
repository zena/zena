module Zena
  module Use
    module Fixtures
      # load all fixtures and setup fixture_accessors:
      FIXTURE_PATH = File.join(RAILS_ROOT, 'test', 'fixtures')
      FILE_FIXTURES_PATH = File.join(RAILS_ROOT, 'test', 'fixtures', 'files')
      # We use transactional fixtures with a single load for ALL tests (this is not the default rails implementation). Tests are now 5x-10x faster.

      def self.included(base)
        self.load_fixtures unless defined?(@@loaded_fixtures)
      end

      # Could DRY with file_path defined in Base
      def self.file_path(filename, content_id)
        digest = Digest::SHA1.hexdigest(content_id.to_s)
        fname = filename.split('.').first
        "#{SITES_ROOT}/test.host/data/full/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"
      end

      def self.load_fixtures
        # make sure versions is of type InnoDB if testing with mysql (transaction support)
        begin
          Node.connection.remove_index "versions", ["title", "text", "summary"]
        rescue ActiveRecord::StatementInvalid
        ensure
          Zena::Db.change_engine('versions', 'InnoDB')
        end

        # Our version of loaded fixtures to help define "users_id", "nodes_id" and such.
        @@loaded_fixtures = {}
        fixture_table_names = []

        # no fixtures ? execute rake task
        unless File.exist?(File.join(FIXTURE_PATH, 'nodes.yml'))
          puts "No fixtures in 'test/fixtures'. Building from 'test/sites'."
          `cd #{RAILS_ROOT} && rake zena:build_fixtures`
        end

        # make sure files and import directories are in sync
        if RAILS_ROOT != Zena::ROOT
          ['test/fixtures/files', 'test/fixtures/import'].each do |path|
            from_dir = "#{Zena::ROOT}/#{path}"
            FileUtils.mkpath(from_dir) unless File.exist?(from_dir)
            Dir.foreach(from_dir) do |f|
              FileUtils.cp_r("#{from_dir}/#{f}", "#{RAILS_ROOT}/#{path}/") unless File.exist?("#{RAILS_ROOT}/#{path}/#{f}")
            end
          end
        end

        Dir.foreach(FIXTURE_PATH) do |file|
          next unless file =~ /^(.+)\.yml$/
          table_name = $1
          fixture_table_names << table_name

          if ['users', 'sites'].include?(table_name)

            define_method(table_name) do |fixture|
              if @@loaded_fixtures[table_name][fixture.to_s]
                # allways reload
                @@loaded_fixtures[table_name][fixture.to_s].find
              else
                raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
              end
            end

            define_method(table_name + "_id") do |fixture|
              Zena::FoxyParser::multi_site_id(fixture)
            end
          else

            define_method(table_name) do |fixture|
              raise Exception.new("$_test_site is blank!") if $_test_site.blank?
              fixture_name = "#{$_test_site}_#{fixture}"
              if fix = @@loaded_fixtures[table_name][fixture_name]
                # allways reload
                fix.find
              else
                raise StandardError, "No fixture with name '#{fixture_name}' found for table '#{table_name}' in site '#{$_test_site}'."
              end
            end

            define_method(table_name + "_id") do |fixture|
              raise Exception.new("$_test_site is blank!") if $_test_site.blank?
              Zena::FoxyParser::id($_test_site, fixture)
            end
          end

          if table_name == 'nodes' || table_name == 'zips'
            define_method(table_name + "_zip") do |fixture|
              # needed by additions_test
              fixture_name = table_name == 'zips' ? fixture.to_s : "#{$_test_site}_#{fixture}"
              if fix = @@loaded_fixtures[table_name][fixture_name]
                fix.instance_eval { @fixture['zip'].to_i }
              else
                raise StandardError, "No fixture with name '#{fixture_name}' found for table '#{table_name}'"
              end
            end
          end

          if table_name == 'sites'
            define_method("#{table_name}_host") do |fixture|
              if fix = @@loaded_fixtures[table_name][fixture]
                fix.instance_eval { @fixture['host'] }
              else
                raise StandardError, "No fixture with name '#{fixture}' found for '#{table_name}'"
              end
            end
          end
        end

        fixtures = ::Fixtures.create_fixtures(FIXTURE_PATH, fixture_table_names)
        unless fixtures.nil?
          if fixtures.instance_of?(::Fixtures)
            @@loaded_fixtures[fixtures.table_name] = fixtures
          else
            fixtures.each { |f| @@loaded_fixtures[f.table_name] = f }
          end
        end

        unless File.exist?("#{SITES_ROOT}/test.host/data")
          @@loaded_fixtures['document_contents'].each do |name,fixture|
            fname, content_id = fixture.instance_eval { [@fixture['name']+"."+@fixture['ext'], @fixture['id'].to_s] }
            path = file_path(fname, content_id)
            FileUtils::mkpath(File.dirname(path))
            if File.exist?(File.join(FILE_FIXTURES_PATH,fname))
              FileUtils::cp(File.join(FILE_FIXTURES_PATH,fname),path)
            end
          end
        end

        unless File.exist?("#{SITES_ROOT}/test.host/public")
          FileUtils::mkpath("#{SITES_ROOT}/test.host/public")
          ['images', 'calendar', 'stylesheets', 'javascripts'].each do |dir|
            FileUtils.symlink_or_copy("../../../public/#{dir}", "#{SITES_ROOT}/test.host/public/#{dir}")
          end
        end

        FileUtils::mkpath("#{SITES_ROOT}/test.host/log") unless File.exist?("#{SITES_ROOT}/test.host/log")
      end
    end # Fixtures
  end # use
end # Zena