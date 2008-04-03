require 'test/unit'
require 'yaml'
require File.join(File.dirname(__FILE__) , '..', 'lib', 'query_builder')

module YamlTest
  module Helper
    def self.included(obj)
      obj.extend YamlTest::ClassMethods
    end
  end
  
  module ClassMethods
    def yaml_test(*files)
      if files[0].kind_of?(Hash)
        files = files[0]
      else
        files = Hash[*(files.map {|f| [f,{}]}.flatten)]
      end
      
      # We need to do a class_eval so that the class variables 'test_strings, test_methods, ...' are scoped
      # in the final class and are not global to all tests using the YamlTest helper.
      class_eval %Q{
        @@test_strings = {}
        @@test_methods = {}
        @@test_options = {}
        @@test_files = []
        #{files.inspect}.each do |file, opts|
          file = file.to_s
          mod_name = opts.delete(:module) || file
          mod_name = mod_name.to_s.split("_").first.capitalize
          strings = {}
          test_methods = []
          YAML::load_documents( File.open( File.join(File.dirname(__FILE__), "\#{file}.yml") ) ) do |doc|
            doc.each do |elem|
              test_methods << elem[0]
              strings[elem[0]] = elem[1]
            end
          end
          class_eval "
            def \#{file}
              @@test_strings['\#{file}']
            end
          "
          @@test_strings[file] = strings.freeze
          @@test_methods[file] = test_methods
          @@test_options[file] = opts
          @@test_files << file
        
        
          # Override this in your test class
          def parse(value)
            value
          end

          def do_test(file, test)
            res = parse(@@test_strings[file][test]['src'])
            if @@test_strings[file][test]['res']
              if @@test_strings[file][test]['res'][0..0] == "/"
                assert_match %r{\#{@@test_strings[file][test]['res'][1..-2]}}m, res
              else
                assert_equal @@test_strings[file][test]['res'], res
              end
            end
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