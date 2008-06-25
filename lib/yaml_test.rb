require 'test/unit'
require 'yaml'

module YamlTest
  module Helper
    def self.included(obj)
      obj.extend YamlTest::ClassMethods
    end
  end
  
  module ClassMethods
    def yaml_dir(file_directory)
      class_eval %Q{
        @@file_directory = #{file_directory.inspect}
      }
    end
    
    def yaml_test(*files)
      # We need to do a class_eval so that the class variables 'test_strings, test_methods, ...' are scoped
      # in the final class and are not global to all tests using the YamlTest helper.
      
      directory = begin
        if caller[0].split('/').last =~ /^(.*)_test.rb/
          File.join(File.dirname(caller[0]), $1)
        else
          puts "Bad file name for yaml_tests '#{caller[0]}'. Should be '..._test.rb'. Trying main directory."
          File.dirname(caller[0])
        end
      end
      
      if files[0].kind_of?(Hash)
        file_list = files[0]
      elsif files.size > 0
        file_list = Hash[*(files.map{|f| [f,{}]}.flatten)]
      else
        file_list = {}
        Dir.foreach(directory) do |f|
          next unless f =~ /^([\w_-]+).yml/
          file_list[$1.to_sym] = {}
        end
      end
      
      
      class_eval %Q{
        @@test_strings = {}
        @@test_methods = {}
        @@test_options = {}
        @@test_files = []
        @@file_list  = #{file_list.inspect}
        @@file_directory ||= #{directory.inspect}
        
        @@file_list.each do |file, opts|
          file = file.to_s
          strings = {}
          test_methods = []
          begin
            YAML::load_documents( File.open( File.join(@@file_directory, "\#{file}.yml") ) ) do |doc|
              doc.each do |elem|
                test_methods << elem[0]
                strings[elem[0]] = elem[1]
              end
            end
          rescue ArgumentError => err
            puts "Error while loading test file \#{File.join(@@file_directory, "\#{file}.yml")}"
            raise err
          end
          class_eval "
            def \#{file}
              @@test_strings['\#{file}']
            end
          "
          @@test_strings[file] = strings.freeze
          @@test_methods[file] = test_methods
          @@test_files << file
        end
        
        # Override this in your test class
        def parse(value)
          value
        end
        
        def do_test(file, test)
          context = @@test_strings[file][test]['context'] || {}
          default_context = (@@test_strings[file]['default'] || {})['context'] || {}
          context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
          res = parse(@@test_strings[file][test]['src'] || test.gsub('_',' '), context)
          if test_res = @@test_strings[file][test]['res']
            assert_yaml_test test_res, res
          end
        end
        
        protected
          def assert_yaml_test(test_res, res)
            if test_res[0..1] == '!/'
              assert_no_match %r{\#{test_res[2..-2]}}m, res
            elsif test_res[0..0] == '/'
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