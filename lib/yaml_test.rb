require 'test/unit'
require 'yaml'

module YamlTest
  module Helper
    def self.included(obj)
      obj.extend YamlTest::ClassMethods
    end
  end
  
  module ClassMethods
    
    # build an array of file_name, file_path, options
    def file_list(caller_dir, opts)
      directories = opts[:directories] || [:default]
      
      if files = opts[:files]
        files.map!{|f| f.to_s}
      end
      
      directories = directories.map do |dir|
        if dir == :default
          if caller_dir.split('/').last =~ /^(.*)_test.rb/
            directories = [File.join(File.dirname(caller_dir), $1)]
          else
            puts "Bad file name for yaml_tests '#{caller_dir}'. Should be '..._test.rb'. Trying parent directory."
            directories = [File.dirname(caller_dir)]
          end
        else
          Dir[dir]
        end
      end.flatten

      file_list = []
      
      directories.each do |dir|
        Dir.foreach(dir) do |f|
          next unless f =~ /^([\w_-]+).yml/
          next if files && !files.include?($1)
          file_list << [$1, File.join(dir, "#{$1}.yml"), opts[$1] || opts[$1.to_sym] || {}]
        end
      end
      
      file_list
    end
    
    
    # Setup yaml testing.
    # usage:
    # class SuperTest < Test::Unit::TestCase
    #   yaml_test
    #
    # or to define custom search directories for tests definitions
    # class SuperTest < Test::Unit::TestCase
    #   yaml_test :directories => ["sub/**", "/absolute/location"]
    #
    # to use only some files:
    # class SuperTest < Test::Unit::TestCase
    #   yaml_test :files => ["one", "two"]
    #
    # to pass parameters during testing of a specific file:
    # class SuperTest < Test::Unit::TestCase
    #   yaml_test :options => {:latex => {:module => Latex}}
    #
    def yaml_test(opts = {})
      # We need to do a class_eval so that the class variables 'test_strings, test_methods, ...' are scoped
      # in the final class and are not global to all tests using the YamlTest helper.
      
      class_eval %Q{
        @@test_strings = {}
        @@test_methods = {}
        @@test_options = {}
        @@test_files = []
        
        file_list(#{caller[0].inspect}, #{opts.inspect}).each do |file_name, file_path, opts|
          strings = {}
          test_methods = []
          begin
            YAML::load_documents( File.open( file_path ) ) do |doc|
              doc.each do |elem|
                test_methods << elem[0]
                strings[elem[0]] = elem[1]
              end
            end
          rescue ArgumentError => err
            puts "Error while loading test file \#{file_path}"
            raise err
          end
          class_eval "
            def \#{file_name}
              @@test_strings['\#{file_name}']
            end
          "
          @@test_strings[file_name] = strings.freeze
          @@test_methods[file_name] = test_methods
          @@test_files << file_name
        end
        
        # Override this in your test class
        def parse(key, source, context)
          source
        end
        
        def do_test(file, test)
          context = @@test_strings[file][test]['context'] || {}
          default_context = (@@test_strings[file]['default'] || {})['context'] || {}
          context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
          @@test_strings[file][test].keys.each do |key|
            next if ['src', 'context'].include?(key)
            assert_yaml_test @@test_strings[file][test][key], parse(key, @@test_strings[file][test]['src'] || test.gsub('_',' '), context)
          end
        end
        
        protected
          def assert_yaml_test(test_res, res)
            if test_res.kind_of?(String) && test_res[0..1] == '!/'
              assert_no_match %r{\#{test_res[2..-2]}}m, res
            elsif test_res.kind_of?(String) && test_res[0..0] == '/'
              assert_match %r{\#{test_res[1..-2]}}m, res
            else
              assert_equal test_res, res
            end
          end
      }
    end
    
    def make_tests
      class_eval %q{
        return unless @@test_methods
        tests = self.instance_methods.reject! {|m| !( m =~ /^test_/ )}
        @@test_files.each do |tf|
          @@test_methods[tf].each do |test|
            unless tests.include?("test_#{tf}_#{test}")
              tests << "test_#{tf}_#{test}"
              class_eval <<-END
                def test_#{tf}_#{test}
                  do_test(#{tf.inspect}, #{test.inspect})
                end
              END
            end
          end
        end
      }
    end
  end
end

Test::Unit::TestCase.send :include, YamlTest::Helper